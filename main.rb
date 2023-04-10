# frozen_string_literal: true

require 'English'
require 'net/http'
require 'json'

BROWSERSTACK_DOMAIN                = 'https://api-cloud.browserstack.com'
APP_UPLOAD_ENDPOINT                = '/app-automate/espresso/v2/app'
TEST_SUITE_UPLOAD_ENDPOINT         = '/app-automate/espresso/v2/test-suite'
APP_AUTOMATE_BUILD_ENDPOINT        = '/app-automate/espresso/v2/build'
APP_AUTOMATE_BUILD_STATUS_ENDPOINT = '/app-automate/espresso/v2/builds/'

def env_has_key(key)
  !ENV[key].nil? && ENV[key] != '' ? ENV[key] : abort("Missing #{key}.")
end

def run_command(cmd)
  puts "@@[command] #{cmd}"
  output = `#{cmd}`
  raise 'Command failed' unless $CHILD_STATUS.success?

  output
end

def upload(file, endpoint, username, access_key)
  uri = URI.parse("#{BROWSERSTACK_DOMAIN}#{endpoint}")
  req = Net::HTTP::Post.new(uri.request_uri)
  req.basic_auth(username, access_key)
  form_data = [['file', File.open(file)]]
  req.set_form(form_data, 'multipart/form-data')
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end
  JSON.parse(res.body, symbolize_names: true)
end

def post(payload, endpoint, username, access_key)
  uri = URI.parse("#{BROWSERSTACK_DOMAIN}#{endpoint}")
  req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
  req.body = payload
  req.basic_auth(username, access_key)
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(req)
  end
  JSON.parse(res.body, symbolize_names: true)
end

def build(payload, app_url, test_suite_url, username, access_key)
  payload = payload.sub('AC_BROWSERSTACK_APP_URL', app_url)
  payload = payload.sub('AC_BROWSERSTACK_TEST_URL', test_suite_url)
  result = post(payload, APP_AUTOMATE_BUILD_ENDPOINT, username, access_key)
  if result[:message] == 'Success'
    puts 'Build started successfully'
    result[:build_id]
  else
    puts 'Build failed'
    exit 1
  end
end

def test_results(build_id, devices, username, access_key)
  devices.each do |device|
    uri = URI.parse("#{BROWSERSTACK_DOMAIN}#{APP_AUTOMATE_BUILD_STATUS_ENDPOINT}#{build_id}/sessions/#{device[:sessions][0][:id]}/report")
    req = Net::HTTP::Get.new(uri.request_uri,
                             { 'Content-Type' => 'application/xml' })
    req.basic_auth(username, access_key)

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
    file_name = "#{device[:device]}.xml"
    output_file = File.join(ENV['AC_OUTPUT_DIR'], file_name)
    File.write(output_file, res.body)
  end
end

def check_status(build_id, test_timeout, username, access_key)
  if test_timeout <= 0
    puts('Plan timed out')
    exit(1)
  end
  uri = URI.parse("#{BROWSERSTACK_DOMAIN}#{APP_AUTOMATE_BUILD_STATUS_ENDPOINT}#{build_id}")

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
  status = response[:status]
  if status != 'running' && status != ''
    puts('Execution finished')
    test_results(build_id, response[:devices], username, access_key) if response[:devices]
    if status == 'failed'
      puts('Test plan failed')
      exit(1)
    end
  else
    puts('Test plan is still running...')
    STDOUT.flush
    sleep(10)
    check_status(build_id, test_timeout - 10, username, access_key)
    true
  end
end

apk_path = env_has_key('AC_APK_PATH')
test_apk_app = env_has_key('AC_TEST_APK_PATH')

username = env_has_key('AC_BROWSERSTACK_USERNAME')
access_key = env_has_key('AC_BROWSERSTACK_ACCESS_KEY')
test_timeout = env_has_key('AC_BROWSERSTACK_TIMEOUT').to_i
payload = env_has_key('AC_BROWSERSTACK_PAYLOAD')

puts "Uploading APK #{apk_path}"
STDOUT.flush
app_url = upload(apk_path, APP_UPLOAD_ENDPOINT, username, access_key)[:app_url]
puts "App uploaded. #{app_url}"
puts "Uploading Test APK #{test_apk_app}"
STDOUT.flush
test_suite_url = upload(test_apk_app, TEST_SUITE_UPLOAD_ENDPOINT, username, access_key)[:test_suite_url]
puts "Test uploaded. #{test_suite_url}"
puts 'Starting a build'
STDOUT.flush
build_id = build(payload, app_url, test_suite_url, username, access_key)
check_status(build_id, test_timeout, username, access_key)
