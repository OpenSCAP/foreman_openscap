require 'test_plugin_helper'

class ComplianceStatusTest < ActiveSupport::TestCase
  def setup
    disable_orchestration
    User.current = users :admin
    ForemanOpenscap::Policy.any_instance.stubs(:ensure_needed_puppetclasses).returns(true)
    @policy_a = FactoryBot.create(:policy)
    @policy_b = FactoryBot.create(:policy)
    @host = FactoryBot.create(:compliance_host)
    @failed_report = FactoryBot.create(:arf_report, :host_id => @host.id)
    @failed_report.stubs(:failed?).returns(true)
    @passed_report = FactoryBot.create(:arf_report, :host_id => @host.id)
    @passed_report.stubs(:failed?).returns(false)
    @passed_report.stubs(:othered?).returns(false)
    @othered_report = FactoryBot.create(:arf_report, :host_id => @host.id)
    @othered_report.stubs(:failed?).returns(false)
    @othered_report.stubs(:othered?).returns(true)
  end

  test 'status should be incompliant' do
    status = ForemanOpenscap::ComplianceStatus.new
    host = FactoryBot.create(:compliance_host, :policies => [@policy_a])
    status.host = host
    host.stubs(:last_report_for_policy).returns(@failed_report)
    status.to_status
    assert_equal 2, status.to_status
  end

  test 'status should be inconclusive' do
    status = ForemanOpenscap::ComplianceStatus.new
    host = FactoryBot.create(:compliance_host, :policies => [@policy_a])
    host.stubs(:last_report_for_policy).returns(@othered_report)
    status.host = host
    assert_equal 1, status.to_status
  end

  test 'status should be compliant' do
    status = ForemanOpenscap::ComplianceStatus.new
    host = FactoryBot.create(:compliance_host, :policies => [@policy_a])
    host.stubs(:last_report_for_policy).returns(@passed_report)
    status.host = host
    assert_equal 0, status.to_status
  end

  test 'status should be incompliant for multiple policies' do
    status = ForemanOpenscap::ComplianceStatus.new
    host = FactoryBot.create(:compliance_host, :policies => [@policy_a, @policy_b])
    status.host = host
    host.stubs(:last_report_for_policy).returns(@failed_report, @passed_report)
    assert_equal 2, status.to_status
  end

  test 'status should be inconclusive for multiple policies' do
    status = ForemanOpenscap::ComplianceStatus.new
    host = FactoryBot.create(:compliance_host, :policies => [@policy_a, @policy_b])
    host.stubs(:last_report_for_policy).returns(@othered_report, @passed_report)
    status.host = host
    assert_equal 1, status.to_status
  end

  test 'status should be compliant for multiple policies' do
    status = ForemanOpenscap::ComplianceStatus.new
    host = FactoryBot.create(:compliance_host, :policies => [@policy_a, @policy_b])
    passed_report = FactoryBot.create(:arf_report, :host_id => @host.id)
    passed_report.stubs(:othered?).returns(false)
    passed_report.stubs(:failed?).returns(false)
    host.stubs(:last_report_for_policy).returns(passed_report, @passed_report)
    status.host = host
    assert_equal 0, status.to_status
  end
end
