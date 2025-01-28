require 'test_plugin_helper'

class BulkUploadTest < ActiveSupport::TestCase
  setup do
    ForemanOpenscap::ScapContent.all.map(&:destroy)
  end

  test 'upload_from_files should create only one scap content' do
    scap_files = ["#{ForemanOpenscap::Engine.root}/test/files/scap_contents/ssg-fedora-ds.xml"]
    assert_difference('ForemanOpenscap::ScapContent.count', 1) do
      2.times do
        ForemanOpenscap::BulkUpload.new.upload_from_files(scap_files)
      end
    end
  end

  test 'upload_from_files should not crash when scap files are not array' do
    scap_files = '/tmp/foo'
    res = ForemanOpenscap::BulkUpload.new.upload_from_files(scap_files)
    assert_equal "Expected an array of files to upload, got: #{scap_files}.", res.errors.first
  end

  test 'upload_from_files should skip directories' do
    dir = "#{ForemanOpenscap::Engine.root}/test/files/scap_contents"
    res = ForemanOpenscap::BulkUpload.new.upload_from_files([dir])
    assert_equal "#{dir} is a directory, expecting file.", res.errors.first
  end

  test 'upload_from_files should skip files that does not exist' do
    file = "#{ForemanOpenscap::Engine.root}/test/files/scap_contents/foo-ds.xml"
    res = ForemanOpenscap::BulkUpload.new.upload_from_files([file])
    assert_equal "#{file} does not exist, skipping.", res.errors.first
  end

  test 'upload_from_directory should check if directory exists' do
    dir = "#{ForemanOpenscap::Engine.root}/test/files/scap_contents/foo"
    res = ForemanOpenscap::BulkUpload.new.upload_from_directory(dir)
    assert_equal "No such directory: #{dir}. Please check the path you have provided.", res.errors.first
  end

  test 'upload_from_directory should upload from directory' do
    dir = "#{ForemanOpenscap::Engine.root}/test/files/scap_contents"
    assert_difference('ForemanOpenscap::ScapContent.count', 1) do
      ForemanOpenscap::BulkUpload.new.upload_from_directory(dir)
    end
  end

  test 'should handle case when scap security guide is not installed' do
    upload = ForemanOpenscap::BulkUpload.new
    upload.stubs(:package_installed?).returns(false)
    res = upload.upload_from_scap_guide
    assert_equal "Can't find scap-security-guide RPM(s), are you sure it is installed on your server?", res.errors.first
  end

  test 'should upload files from guide' do
    upload = ForemanOpenscap::BulkUpload.new
    upload.stubs(:package_installed?).returns(true)
    upload.stubs(:files_from_guide).returns(["#{ForemanOpenscap::Engine.root}/test/files/scap_contents/ssg-fedora-ds.xml"])
    assert_difference('ForemanOpenscap::ScapContent.count', 1) do
      upload.upload_from_scap_guide
    end
  end

  test 'should upload new files from guide' do
    upload = ForemanOpenscap::BulkUpload.new
    upload.stubs(:package_installed?).returns(true)
    upload.stubs(:files_from_guide).returns(["#{ForemanOpenscap::Engine.root}/test/files/scap_contents/cs9-old/ssg-cs9-ds.xml"])
    assert_difference('ForemanOpenscap::ScapContent.count', 1) do
      upload.upload_from_scap_guide
    end
    old_digest = ForemanOpenscap::ScapContent.last.digest
    upload.stubs(:files_from_guide).returns(["#{ForemanOpenscap::Engine.root}/test/files/scap_contents/cs9-new/ssg-cs9-ds.xml"])
    assert_no_difference('ForemanOpenscap::ScapContent.count') do
      upload.upload_from_scap_guide
    end
    new_digest = ForemanOpenscap::ScapContent.last.digest
    refute_equal old_digest, new_digest
  end
end
