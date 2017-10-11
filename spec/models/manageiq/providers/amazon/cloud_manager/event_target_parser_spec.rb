describe ManageIQ::Providers::Amazon::CloudManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryGirl.create(:ems_amazon, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "AWS Config Event" do
    it "parses vm_ems_ref into event" do
      ems_event = create_ems_event("sqs_message.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-06199fba'}])
    end

    it "CloudFormation_StackCreate" do
      ems_event = create_ems_event("config/AWS_CloudFormation_Stack_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to(
        match_array([{:ems_ref=>"arn:aws:cloudformation:us-east-1:200278856672:stack/ladas-test31/0fb199a0-93c4-11e7-998e-500c217b4a62"}])
      )
    end

    it "CloudFormation_StackDelete" do
      ems_event = create_ems_event("config/AWS_CloudFormation_Stack_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to(
        match_array([{:ems_ref=>"arn:aws:cloudformation:us-east-1:200278856672:stack/ladas-test-22/ec875e20-93a9-11e7-b549-500c28b23699"}])
      )
    end
  end

  context "AWS CloudWatch with CloudTrail API" do
    it "parses AWS_API_CALL_StartInstances event" do
      ems_event = create_ems_event("cloud_watch/AWS_API_CALL_StartInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses AWS_API_CALL_StopInstances" do
      ems_event = create_ems_event("cloud_watch/AWS_API_CALL_StopInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end
  end

  context "AWS CloudWatch EC2" do
    it "parses EC2_Instance_State_change_Notification_pending event" do
      ems_event = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_pending.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses EC2_Instance_State_change_Notification_running event" do
      ems_event = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_running.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses EC2_Instance_State_change_Notification_stopped event" do
      ems_event = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_stopped.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end
  end

  context "AWS CloudWatch Alarm" do
    it "parses AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts alarm event" do
      ems_event = create_ems_event("cloud_watch/AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end
  end

  def response(path)
    response = double
    allow(response).to receive(:body).and_return(
      File.read(File.join(File.dirname(__FILE__), "/event_catcher/#{path}"))
    )

    allow(response).to receive(:message_id).and_return("mocked_message_id")

    response
  end

  def create_ems_event(path)
    event = ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream.new(double).send(:parse_event, response(path))
    event_hash = ManageIQ::Providers::Amazon::CloudManager::EventParser.event_to_hash(event, @ems.id)
    EmsEvent.add(@ems.id, event_hash)
  end
end
