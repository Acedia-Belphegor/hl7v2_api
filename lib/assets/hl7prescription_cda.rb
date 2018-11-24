# encoding: utf-8
require 'cda'
require 'json'
require 'date'
require 'nokogiri'
require 'virtus_annotations'
require_relative 'hl7parser'

class HL7PrescriptionCda
    def initialize(raw_message)
        @parser = HL7Parser.new(raw_message)

        @jahis_tables = open(Rails.root.join('lib/assets/json/JAHIS_TABLES.json')) do |io|
        # @jahis_tables = open("./json/JAHIS_TABLES.json") do |io|
            JSON.load(io)
        end
    end

    def generate_cda()
        @clinical_document = Cda::ClinicalDocument.new()

        # 対象地域
        realm_code = Cda::CS.new()
        realm_code.code = 'JP'  # "JP"（日本）
        @clinical_document.realm_code.push(realm_code)

        type_id = Cda::InfrastructureRootTypeId.new()
        type_id.root = '2.16.840.1.113883.1.3'
        type_id.extension = 'POCD_HD000040'
        @clinical_document.type_id = type_id

        # 処方箋ID
        id = Cda::II.new()
        id.root = '1.2.392.100495.20.3.11'  # 処方箋IDを示すOID
        id.extension = 0
        @clinical_document.id = id

        # 文書区分コード
        code = Cda::CE.new()
        code.code = '01'  # 01:処方箋
        code.code_system = '1.2.392.100495.20.2.11'
        @clinical_document.code = code

        # 文書名
        title = Cda::ST.new()
        title._text = '処方箋'
        @clinical_document.title = title

        # 文書作成日時
        effective_time = Cda::TS.new()
        effective_time.value = Time.now.strftime("%Y%m%d%H%M%S")
        @clinical_document.effective_time = effective_time

        # 守秘レベルコード
        confidentiality_code = Cda::CE.new()
        confidentiality_code.code = 'N'  # N:Normal
        confidentiality_code.code_system = '2.16.840.1.113883.5.25'
        @clinical_document.confidentiality_code = confidentiality_code

        # 本記述仕様のバージョン番号
        version_number = Cda::INT.new()
        version_number.value = 100  # V.1.00を示す
        @clinical_document.version_number = version_number

        # 患者情報
        record_target = generate_record_target()
        @clinical_document.record_target.push(record_target)

        # 処方箋発行機関情報
        author = generate_author()
        @clinical_document.author.push(author)

        # ボディ部
        component = generate_component()
        @clinical_document.component = component
        
        return build_document()
    end

    private
    def build_document()
        builder = Cda::XmlBuilder.new(@clinical_document, 'ClinicalDocument')
        return builder.build_document.tap(&:remove_namespaces!)
    end

    # 患者情報
    def generate_record_target()
        record_target = Cda::RecordTarget.new()
        patient_role = Cda::PatientRole.new()
        patient = Cda::Patient.new()

        # PIDセグメント取得
        pid_segment = @parser.get_parsed_segments('PID')       
        if pid_segment.nil? then
            return nil
        end        
        pid_segment.first.each do |field|
            case field['name']
            when 'Patient Identifier List' then
                # 患者ID
                id = Cda::II.new()
                id.root = '1.2.392.100495.20.3.51.1' + get_sending_facility()
                id.extension = field['value']
                patient_role.id.push(id)
            when 'Patient Name' then
                # 患者氏名
                field['array_data'].each do |repeat_field|
                    name = Cda::PN.new()
                    repeat_field.each do |element|
                        case element['name']
                        when 'Family Name' then
                            # 姓
                            family = Cda::EnFamily.new()
                            family._text = element['value']
                            name.family.push(family)
                        when 'Given Name' then
                            # 名
                            given = Cda::EnGiven.new()
                            given._text = element['value']
                            name.given.push(given)
                        when 'Name Representation Code' then
                            case element['value']
                            when 'I' then
                                # 漢字
                                name.use = 'IDE'
                            when 'P' then
                                # カナ
                                name.use = 'SYL'
                            end
                        end
                    end
                    patient.name.push(name)
                end
            when 'Date/Time of Birth' then
                # 生年月日
                birth = Cda::TS.new()
                birth.value = field['value']
                patient.birth_time = birth
            when 'Administrative Sex' then
                # 性別
                gender = Cda::CE.new()
                gender.code = field['value']
                gender.code_system = '2.16.840.1.113883.5.1'
                patient.administrative_gender_code = gender
            when 'Patient Address' then
                # 患者の住所
                patient_role.addr.push(xad_to_ad(field))
            when 'Phone Number - Home' then
                # 電話番号-自宅
                if !field['array_data'].nil? then
                    field['array_data'].first.each do |element|
                        case element['name']
                        when 'Telephone Number' then
                            telecom = Cda::TEL.new()
                            telecom.value = element['value']
                            telecom.use = 'HP'
                            patient_role.telecom.push(telecom)
                        end
                    end
                end
            when 'Phone Number - Business' then
                # 電話番号-勤務先
                if !field['array_data'].nil? then
                    field['array_data'].first.each do |element|
                        case element['name']
                        when 'Telephone Number' then
                            telecom = Cda::TEL.new()
                            telecom.value = element['value']
                            telecom.use = 'WP'
                            patient_role.telecom.push(telecom)
                        end
                    end    
                end
            end
        end
        patient_role.patient = patient
        record_target.patient_role = patient_role
        return record_target
    end

    # 処方箋発行機関情報
    def generate_author()
        author = Cda::Author.new()

        # 処方医情報
        assigned_author = Cda::AssignedAuthor.new()

        # ORCセグメント取得
        orc_segment = @parser.get_parsed_segments('ORC')
        if orc_segment.nil? then
            return nil
        end
        # 処方医情報
        assigned_person = Cda::Person.new()
        name = Cda::PN.new()
        name.use = 'IDE'

        # 医療機関情報
        represented_organization = Cda::Organization.new()
        sending_facility = get_sending_facility()
        # 都道府県番号
        if sending_facility.length >= 2 then
            id = Cda::II.new()
            id.root = '1.2.392.100495.20.3.21'
            id.extension = sending_facility[0, 2]
            represented_organization.id.push(id)
        end
        # 点数表番号
        if sending_facility.length >= 3 then
            id = Cda::II.new()
            id.root = '1.2.392.100495.20.3.22'
            id.extension = sending_facility[2, 1]
            represented_organization.id.push(id)
        end
        # 医療機関コード
        if sending_facility.length >= 10 then
            id = Cda::II.new()
            id.root = '1.2.392.100495.20.3.23'
            id.extension = sending_facility[3, 7]
            represented_organization.id.push(id)
        end
        orc_segment.first.each do |field|
            case field['name']
            when 'Date/Time of Transaction' then
                # 交付年月日
                time = Cda::IVL_TS.new()
                low = Cda::IVXB_TS.new()
                low.value = field['value'].to_date
                time.low = low
                author.time = time
            when 'Ordering Provider' then
                # 依頼者
                field['array_data'].first.each do |element|
                    case element['name']
                    when 'ID Number' then
                        # 処方医ID
                        id = Cda::II.new()
                        id.root = '1.2.392.100495.20.3.41.1' + get_sending_facility()
                        id.extension = element['value']
                        assigned_author.id.push(id)
                    when 'Family Name' then
                        # 姓
                        family = Cda::EnFamily.new()
                        family._text = element['value']
                        name.family.push(family)
                    when 'Given Name' then
                        # 名
                        given = Cda::EnGiven.new()
                        given._text = element['value']
                        name.given.push(given)
                    end
                end
            when 'Ordering Facility Name' then
                # 医療機関名称
                name = Cda::ON.new()
                name.use = 'IDE'
                name._text = field['value']
                represented_organization.name.push(name)
            when 'Ordering Facility Address' then
                # 医療機関所在地
                represented_organization.addr.push(xad_to_ad(field))
            when 'Entering Organization' then
                # 処方医所属診療科情報
                organization_part_of = Cda::OrganizationPartOf.new()
                code = Cda::CE.new()
                code.code_system = '1.2.392.100495.20.2.51'
                field['array_data'].first.each do |element|
                    case element['name']
                    when 'Identifier' then
                        # 診療科コード
                        code.code = element['value']
                    when 'Text' then
                        # 診療科名
                        code.display_name = element['value']
                    end
                end
                organization_part_of.code = code
                represented_organization.as_organization_part_of = organization_part_of
            end
        end
        assigned_person.name.push(name)
        assigned_author.represented_organization = represented_organization
        assigned_author.assigned_person = assigned_person
        author.assigned_author = assigned_author
        return author
    end

    # ボディ部
    def generate_component()
        component2 = Cda::Component2.new()
        structured_body = Cda::StructuredBody.new()
        
        # 処方指示セクション
        structured_body.component.push(generate_section_prescription_order())        
        
        # 保険・公費情報セクション
        structured_body.component.push(generate_section_insurance())
        
        # 備考情報セクション
        structured_body.component.push(generate_section_remarks())

        # 補足情報セクション
        structured_body.component.push(generate_section_supplement())

        component2.structured_body = structured_body
        return component2
    end

    # 処方指示セクション
    def generate_section_prescription_order()
        component3 = Cda::Component3.new()
        section = Cda::Section.new()

        # セクション区分：処方指示
        code = Cda::CE.new()
        code.code = '01' # 処方指示
        code.code_system = '1.2.392.100495.20.2.12'
        section.code = code

        # セクションのタイトル
        title = Cda::ST.new()
        title._text = '処方指示'
        section.title = title

        # 処方内容文字列
        sdlist = Cda::StrucDocList.new()

        # ORC,RXE,TQ1,RXR を1つのグループにする
        segments_group = Array[]
        segments = Array[]
        @parser.get_parsed_message().each do |segment|
            if segment[0]['value'] == 'ORC' then
                if !segments.empty? then
                    segments_group.push(segments)
                end
                segments = Array[]
                segments.push(segment)
            else
                if !segments.empty? then
                    segments.push(segment)
                end    
            end
        end
        if !segments.empty? then
            segments_group.push(segments)
        end
        segments_group.each do |segments|
            entry = Cda::Entry.new()
            # 薬剤ごとの処方指示情報
            substance_administration = Cda::SubstanceAdministration.new()
            substance_administration.class_code = 'SBADM'
            substance_administration.mood_code = 'RQO'

            # 分量
            dose_check_quantity = Cda::RTO_PQ_PQ.new()
            dose_check_quantity.numerator = Cda::PQ.new()

            # 医薬品名
            consumable = Cda::Consumable.new()

            # 薬品補足情報
            entry_relationship = Cda::EntryRelationship.new()
            entry_relationship.type_code = 'REFR'
            entry_relationship.inversion_ind = false

            supply = Cda::Supply.new()
            supply.class_code = 'SPLY'
            supply.mood_code = 'RQO'

            segments.each do |segment|
                case segment[0]['value']
                when 'ORC' then
                    segment.each do |field|
                        case field['name']
                        when 'Placer Group Number' then
                            # RP番号
                            id = Cda::II.new()
                            id.root = '1.2.392.100495.20.3.81'
                            id.extension = field['value']
                            substance_administration.id.push(id)

                            # テキスト情報
                            sditem = Cda::StrucDocItem.new()
                            sditem._text = 'RP-' + field['value']
                            sdlist.item.push(sditem)
                        end
                    end
                when 'RXE' then
                    segment.each do |field|
                        case field['name']
                        when 'Give Code' then
                            # 医薬品名                            
                            manufactured_product = Cda::ManufacturedProduct.new()
                            manufactured_labeled_drug = Cda::LabeledDrug.new()
                            code = Cda::CE.new()
                            field['array_data'].first.each do |element|
                                case element['name']
                                when 'Identifier' then
                                    # 薬品コード
                                    code.code = element['value']
                                when 'Text' then
                                    # 薬品名
                                    code.display_name = element['value']

                                    # テキスト情報
                                    sditem = Cda::StrucDocItem.new()
                                    sditem._text = element['value']
                                    sdlist.item.push(sditem)
                                when 'Name of Coding System' then
                                    # コードシステム名
                                    case element['value']
                                    when 'HOT' then
                                        code.code_system = '1.2.392.100495.20.2.74'
                                    else
                                        code.code_system = ''
                                    end
                                end
                            end
                            manufactured_labeled_drug.code = code
                            manufactured_product.manufactured_labeled_drug = manufactured_labeled_drug
                            consumable.manufactured_product = manufactured_product
                        when 'Give Indication' then
                            # 剤型情報
                            code = Cda::CD.new()
                            code.code_system = '1.2.392.100495.20.2.21'

                            case field['value']
                            when '21' then # 内服
                                code.code = '1'
                                code.display_name = '内服'
                            when '22' then # 頓用
                                code.code = '2'
                                code.display_name = '頓服'
                            when '23' then # 外用
                                code.code = '3'
                                code.display_name = '外用'
                            when '24' then # 自己注射
                                code.code = '5'
                                code.display_name = '注射'
                            end
                            substance_administration.code = code
                        when 'Dispense Amount' then
                            # 調剤量
                            quantity = Cda::PQ.new()
                            quantity.value = field['value']
                            supply.quantity = quantity
                        when 'Dispense Units' then
                            # 調剤単位
                            quantity = Cda::PQ.new()
                            if !supply.quantity.nil? then
                                quantity = supply.quantity
                            end
                            field['array_data'].first.each do |element|
                                case element['name']
                                when 'Identifier' then
                                    # 単位(entryRelationship/supply/quantity/@unit)
                                    quantity.unit = element['value']
                                    # 単位(doseCheckQuantity/numerator/@unit)
                                    dose_check_quantity.numerator.unit = element['value']
                                end
                            end
                            supply.quantity = quantity
                        when 'Total Daily Dose' then
                            # 1日あたりの総投与量
                            field['array_data'].first.each do |element|
                                case element['name']
                                when 'Quantity' then
                                    dose_check_quantity.numerator.value = element['value']
                                when 'Units' then
                                    if !element['value'].empty? then
                                        dose_check_quantity.numerator.unit = element['value']
                                    end
                                end
                            end
                        end
                    end
                when 'TQ1' then
                    segment.each do |field|
                        case field['name']
                        when 'Service Duration' then
                            # 投与日数／投与回数
                            effective_time = Cda::IVL_TS.new()
                            width = Cda::PQ.new()
                            field['array_data'].first.each do |element|
                                case element['name']
                                when 'Quantity' then
                                    width.value = element['value']
                                when 'Units' then
                                    if element['value'].include?('日') then
                                        width.unit = 'd' # 内服
                                    else
                                        width.unit = '1' # 他
                                    end
                                end
                            end
                            effective_time.width = width
                            substance_administration.effective_time.push(effective_time)
                        when 'Repeat Pattern' then
                            # 用法
                            effective_time = Cda::EIVL_TS.new()
                            effective_time.operator = 'A' # 固定値
                            # 用法内容
                            event = Cda::EIVLEvent.new()
                            event.code_system = '1.2.392.100495.20.2.31'
                            field['array_data'].first.each do |element|
                                case element['name']
                                when 'Repeat Pattern Code' then
                                    element['array_data'].each do |e|
                                        case e['name']
                                        when 'Identifier' then
                                            # 標準用法コード
                                            event.code = e['value']
                                        when 'Text' then
                                            # 標準用法コード名称
                                            event.display_name = e['value']
                                        end
                                    end
                                    break
                                end
                            end
                            effective_time.event = event
                            substance_administration.effective_time.push(effective_time)
                        end
                    end
                end
            end
            sdtext = Cda::StrucDocText.new()
            sdtext.list = sdlist
            section.text = sdtext
            substance_administration.dose_check_quantity = dose_check_quantity
            substance_administration.consumable = consumable
            entry_relationship.supply = supply
            substance_administration.entry_relationship.push(entry_relationship)
            entry.substance_administration = substance_administration
            section.entry.push(entry)
        end
        component3.section = section
        return component3
    end

    # 保険・公費情報セクション
    def generate_section_insurance()
        component3 = Cda::Component3.new()
        section = Cda::Section.new()

        # セクション区分：処方指示
        code = Cda::CE.new()
        code.code = '11' # 保険・公費情報
        code.code_system = '1.2.392.100495.20.2.12'
        section.code = code

        # セクションのタイトル
        title = Cda::ST.new()
        title._text = '保険・公費情報'
        section.title = title

        entry = Cda::Entry.new()
        
        act = Cda::Act.new()
        act.class_code = 'ACT'
        act.mood_code = 'EVN'

        # レセプト種別
        code = Cda::CD.new()
        code.code = ''
        code.code_system = '1.2.392.100495.20.2.64'
        code.display_name = ''
        act.code = code

        in1_segment = @parser.get_parsed_segments('IN1')
        if in1_segment.nil? then
            return component3
        end

        # 保険情報文字列
        sdlist = Cda::StrucDocList.new()

        in1_segment.each do |segment|
            entry_relationship = Cda::EntryRelationship.new()
            entry_relationship.type_code = 'COMP'
    
            er_act = Cda::Act.new()
            er_act.class_code = 'ACT'
            er_act.mood_code = 'EVN'
                
            participant = Cda::Participant2.new()
            participant.type_code = 'COV'
            participant_role = Cda::ParticipantRole.new()
    
            segment.each do |field|
                case field['name']
                when 'Insurance Plan ID' then
                    # 法制コード
                    code = Cda::CD.new()
                    code.code_system = '1.2.392.100495.20.2.61'                    
                    field['array_data'].first.each do |element|
                        case element['name']
                        when 'Identifier' then                            
                            code.code = get_insurance_code(element['value'])
                        when 'text' then
                            code.display_name = element['value']                            
                        end
                    end
                    er_act.code = code
                when 'Insurance Company ID' then
                    # 保険者番号 / 公費負担者番号
                    performer = Cda::Performer2.new()
                    assigned_entity = Cda::AssignedEntity.new()
                    id = Cda::II.new()
                    if er_act.code.code == '8' then
                        id.root = '1.2.392.100495.20.3.71' # 公費負担者番号
                    else
                        id.root = '1.2.392.100495.20.3.61' # 保険者番号
                    end                
                    id.extension = field['value']
                    assigned_entity.id.push(id)
                    performer.assigned_entity = assigned_entity
                    er_act.performer.push(performer)

                    # テキスト情報
                    sditem = Cda::StrucDocItem.new()
                    sditem._text = field['value']
                    sdlist.item.push(sditem)
                when 'Insured’s Group Emp ID' then
                    # 記号                
                    if er_act.code.code == '8' then
                        break # 公費の場合は無視する
                    end
                    id = Cda::II.new()
                    id.root = '1.2.392.100495.20.3.62'
                    id.extension = field['value']
                    participant_role.id.push(id)

                    # テキスト情報
                    sditem = Cda::StrucDocItem.new()
                    sditem._text = field['value']
                    sdlist.item.push(sditem)
                when 'Insured’s Group Emp Name' then
                    # 番号
                    if er_act.code.code == '8' then
                        break # 公費の場合は無視する
                    end
                    id = Cda::II.new()
                    id.root = '1.2.392.100495.20.3.63'
                    id.extension = field['value']
                    participant_role.id.push(id)

                    # テキスト情報
                    sditem = Cda::StrucDocItem.new()
                    sditem._text = field['value']
                    sdlist.item.push(sditem)
                when 'Insured’s Relationship To Patient' then
                    # 本人/家族
                    if er_act.code.code == '8' then
                        break # 公費の場合は無視する
                    end
                    code = Cda::CE.new()
                    code.code_system = '1.2.392.100495.20.2.62'
                    field['array_data'].first.each do |element|
                        case element['name']
                        when 'Identifier' then
                            case element['value']
                            when 'SEL', 'EME' then
                                code.code = '1' # 被保険者
                                code.display_name = '被保険者'
                            when 'EXF', 'SPO', 'CHD' then
                                code.code = '2' # 被扶養者
                                code.display_name = '被扶養者'
                            end
                        when 'Text' then
                            sditem = Cda::StrucDocItem.new()
                            sditem._text = element['value']
                            sdlist.item.push(sditem)
                        end
                    end
                    participant_role.code = code
                end
            end
            participant.participant_role = participant_role
            er_act.participant.push(participant)
            entry_relationship.act = er_act
            act.entry_relationship.push(entry_relationship)
        end
        sdtext = Cda::StrucDocText.new()
        sdtext.list = sdlist
        section.text = sdtext
        entry.act = act
        section.entry.push(entry)
        component3.section = section
        return component3
    end

    # 備考情報セクション
    def generate_section_remarks()
        component3 = Cda::Component3.new()
        section = Cda::Section.new()

        # セクション区分：備考情報
        code = Cda::CE.new()
        code.code = '101' # 備考情報
        code.code_system = '1.2.392.100495.20.2.12'
        section.code = code

        # セクションのタイトル
        title = Cda::ST.new()
        title._text = '処方箋備考情報'
        section.title = title

        # 何か書く



        component3.section = section
        return component3
    end

    def generate_section_supplement()
        component3 = Cda::Component3.new()
        section = Cda::Section.new()

        # セクション区分：補足情報
        code = Cda::CE.new()
        code.code = '201' # 補足情報
        code.code_system = '1.2.392.100495.20.2.12'
        section.code = code

        # セクションのタイトル
        title = Cda::ST.new()
        title._text = '処方箋補足情報'
        section.title = title

        # 何か書く



        component3.section = section
        return component3
    end

    def get_insurance_code(value)
        jhsd = @jahis_tables['JHSD0001'].find{|c| c['value'] == value}
        if jhsd.nil? then
            return ''
        end
        case jhsd['type']
        when 'MI' then # 医保
            case jhsd['value']
            when 'C0' then
                '2'  # 国保
            when '39' then
                '7'  # 後期高齢
            else
                '1'  # 社保
            end
        when 'LI' then
            '3'  # 労災
        when 'TI' then
            '4'  # 自賠
        when 'PS' then
            '5'  # 公害
        when 'OE' then
            '6'  # 自費
        when 'PE' then
            '8'  # 公費
        end
    end

    def get_sending_facility()
        return @parser.get_parsed_value('MSH', 'Sending Facility')
    end

    def xad_to_ad(field)
        addr = Cda::AD.new()
        if !field['array_data'].nil? then
            field['array_data'].first.each do |element|
                case element['name']
                when 'Street Address', 'Other Geographic Designation' then
                    # 住所
                    street = Cda::AdxpStreetAddressLine.new()
                    street._text = element['value']
                    addr.street_address_line.push(street)
                when 'City' then
                    # 市区町村
                    city = Cda::AdxpCity.new()
                    city._text = element['value']
                    addr.city.push(city)
                when 'State or Province' then
                    # 都道府県
                    state = Cda::AdxpState.new()
                    state._text = element['value']
                    addr.state.push(state)
                when 'Country' then
                    # 国
                    county = Cda::AdxpCounty.new()
                    county._text = element['value']
                    addr.county.push(county)
                when 'Zip or Postal Code' then
                    # 郵便番号
                    postal_code = Cda::AdxpPostalCode.new()
                    postal_code._text = element['value']
                    addr.postal_code.push(postal_code)
                end
            end
        end
        return addr
    end
end
