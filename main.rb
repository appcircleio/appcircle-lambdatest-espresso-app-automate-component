# frozen_string_literal: true

require 'English'
require 'net/http'
require 'json'
require 'fileutils'

LT_MANUAL_DOMAIN           = 'https://manual-api.lambdatest.com'
LT_MOBILE_DOMAIN           = 'https://mobile-api.lambdatest.com'

APK_UPLOAD_ENDPOINT                = '/app/uploadFramework'
APP_AUTOMATE_BUILD_ENDPOINT        = '/framework/v1/espresso/build'
APP_AUTOMATE_JUNIT_REPORT_ENDPOINT = '/mobile-automation/api/v1/framework/builds/'
APP_AUTOMATE_BUILD_STATUS_ENDPOINT = '/mobile-automation/api/v1/builds/'

def env_has_key(key)
  !ENV[key].nil? && ENV[key] != '' ?  ENV[key] : abort("Missing #{key}.")
end

def run_command(cmd)
  puts "@@[command] #{cmd}"
  output = `#{cmd}`
  raise 'Command failed' unless $CHILD_STATUS.success?

  output
end

def upload(file, endpoint, username, access_key)
  uri = URI.parse("#{LT_MANUAL_DOMAIN}#{endpoint}")
  req = Net::HTTP::Post.new(uri.request_uri)
  req.basic_auth(username, access_key)
  form_data = [['appFile', File.open(file)],['type', 'espresso-android']]

  req.set_form(form_data, 'multipart/form-data')
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end
  JSON.parse(res.body, symbolize_names: true)
end

def post(payload, endpoint, username, access_key)
  uri = URI.parse("#{LT_MOBILE_DOMAIN}#{endpoint}")
  req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
  req.body = payload
  req.basic_auth(username, access_key)
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end
  JSON.parse(res.body, symbolize_names: true)
end

def build(payload, app_url, test_suite_url, username, access_key)
  payload[:app] = app_url
  payload[:testSuite] = test_suite_url
  json_string = payload.to_json
  build_result = post(json_string, APP_AUTOMATE_BUILD_ENDPOINT, username, access_key)
  successful_builds = []
  build_result[:status].each_with_index do |status, index|
    build_id = build_result[:buildId][index]
    message  = build_result[:message][index]
    if status == "Success" && build_id.to_s.strip != ""
      puts "Build #{index+1} started successfully: #{build_id}"
      successful_builds << build_id
    else
      puts "Build #{index+1} failed: #{message}"
    end
  end
  if successful_builds.empty?
    puts "All builds failed. Exiting."
    exit 1
  end
  return successful_builds, build_result
end

def test_results(build_id, device, username, access_key)
  test_report_folder = "#{env_has_key('AC_OUTPUT_DIR')}/test-results"
  FileUtils.mkdir(test_report_folder) unless Dir.exist?(test_report_folder)
  uri = URI.parse("#{LT_MOBILE_DOMAIN}#{APP_AUTOMATE_JUNIT_REPORT_ENDPOINT}#{build_id}/report?encoder=false")
  req = Net::HTTP::Get.new(uri.request_uri, { 'Content-Type' => 'application/xml' })
  req.basic_auth(username, access_key)     
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end
  file_name = "#{device}.xml"
  output_file = File.join(test_report_folder, file_name)
  File.write(output_file, res.body)
  File.open(env_has_key('AC_ENV_FILE_PATH'), 'a') do |f|
    f.puts "AC_LT_TEST_RESULT_PATH=#{test_report_folder}"
  end
end

def check_status(build_id, device_name, test_timeout, username, access_key)
  if test_timeout <= 0
    puts('Plan timed out')
    exit(1)
  end
  uri = URI.parse("#{LT_MOBILE_DOMAIN}#{APP_AUTOMATE_BUILD_STATUS_ENDPOINT}#{build_id}")  
  req = Net::HTTP::Get.new(uri.request_uri,
                           { 'Content-Type' => 'application/json' })
  req.basic_auth(username, access_key)  
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end
  case res
  when Net::HTTPClientError, Net::HTTPServerError
    abort "\nError checking status: #{res.code} (#{res.message})\n\n"
  end
  response = JSON.parse(res.body, symbolize_names: true)
  status = response[:data][:status_ind]
  if status != 'queued' && status != 'running' && status != ''
    puts('Execution finished for build ID: ' + build_id)
    test_results(build_id, device_name, username, access_key) if response[:data][:build_id]
    if status == 'failed'
      puts('Test plan failed for build ID: ' + build_id)
    end
  else
    puts('Test plan is still running... for build ID: ' + build_id)
    STDOUT.flush
    sleep(10)
    check_status(build_id, device_name, test_timeout - 10, username, access_key)
    true
  end
end

def check_status_for_all_builds(build_result, test_timeout, username, access_key)
    threads = []
    build_result[:buildId].each_with_index do |build_id, index|
        status = build_result[:status][index]
        next if status != 'Success' || build_id.to_s.strip == ''
        device_name = build_result[:device][index]
        threads << Thread.new do
            check_status(build_id, device_name, test_timeout, username, access_key)
        end
    end
    threads.each(&:join)
end

apk_path = env_has_key('AC_APK_PATH')
test_apk_app = env_has_key('AC_TEST_APK_PATH')

username = env_has_key('AC_LT_USERNAME')
access_key = env_has_key('AC_LT_ACCESS_KEY')
test_timeout = env_has_key('AC_LT_TIMEOUT').to_i
payload = JSON.parse(env_has_key('AC_LT_PAYLOAD'))

$build_result = {}

puts "Uploading APK #{apk_path}"
STDOUT.flush
app_url = upload(apk_path, APK_UPLOAD_ENDPOINT, username, access_key)[:app_id]
puts "App uploaded #{app_url}"
puts "Uploading Test APK #{test_apk_app}"
STDOUT.flush
test_suite_url = upload(test_apk_app, APK_UPLOAD_ENDPOINT, username, access_key)[:app_id]
puts "Test uploaded #{test_suite_url}"
puts 'Starting a build'
STDOUT.flush
successful_builds, $build_result = build(payload, app_url, test_suite_url, username, access_key)
$build_result[:device] = payload["device"]
puts "Build started with ID: #{successful_builds}"
check_status_for_all_builds($build_result, test_timeout, username, access_key)