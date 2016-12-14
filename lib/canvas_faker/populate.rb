require "highline"
require "lms_api"
require "faker"

module CanvasFaker

  class Populate

    def initialize(canvas_url, token, tools = [])
      @api = LMS::API.new(canvas_url, token)
      @tools = tools
    end

    def cli
      @cli ||= HighLine.new
    end

    def get_account_id
      accounts = @api.all_accounts # gets the accounts
      accounts.each_with_index do |account, index|
        puts "#{index}. #{account['name']}"
      end
      # make the index dynamic to what account they choose.
      answer = cli.ask("Install course under which account? ex.. 2", Integer)
      accounts[answer]["id"]
    end

    def create_course(account_id)
      course_name = cli.ask "Name your new course."
      payload = {
        course: {
          name: course_name,
          # sis_course_id: course_id,
        }
      }
      @api.proxy(
        "CREATE_NEW_COURSE",
        { account_id: account_id },
        payload
      )
    end

    def create_users(account_id)
      num_students = cli.ask(
        "How many students do you want in your course?",
        Integer
      )
      (1..num_students).map do
        user_first_name = Faker::Name.first_name
        user_last_name = Faker::Name.last_name
        payload = {
          user: {
            name: "#{user_first_name} #{user_last_name}",
            short_name: user_first_name,
            sortable_name: "#{user_last_name}, #{user_first_name}",
            terms_of_use: true,
            skip_registration: true,
            avatar: {
              url: Faker::Avatar.image
            }
          },
          pseudonym: {
            unique_id: Faker::Internet.safe_email,
            password: "asdfasdf"
          }
        }
        @api.proxy(
          "CREATE_USER",
          { account_id: account_id },
          payload
        ).tap { |stud| puts "#{stud['name']} creating." }
      end
    end

    def enroll_user_in_course(students, course_id)
      students.each do |student|
        payload = {
          enrollment: {
            user_id: student["id"],
            type: "StudentEnrollment",
            enrollment_state: "active"
          }
        }
        @api.proxy(
          "ENROLL_USER_COURSES",
          { course_id: course_id },
          payload
        )
        puts "Enrolled #{student['name']} into your course_id #{course_id}"
      end
    end

    def install_lti_tool_to_course(course_id)
      return if @tools.empty?
      # Taken from canvas documentation, below.
      # https://canvas.instructure.com/doc/api/external_tools.html
      @tools.each_with_index do |tool, index|
        puts "#{index}. #{tool[:app][:lti_key]}"
      end
      tool_index =
        cli.ask("Which tool do you want to add to your course?", Integer)
      tool = tools[tool_index]
      payload = {
        name: "#{tool[:app][:lti_key]}",
        privacy_level: "public",
        consumer_key: "#{tool[:app][:lti_key]}",
        shared_secret: "#{tool[:app][:lti_secret]}",
        config_type: "by_xml",
        config_xml: "#{tool[:config]}"
      }
      @api.proxy(
        "CREATE_EXTERNAL_TOOL_COURSES",
        { course_id: course_id },
        payload
      )
    end

    def setup_course
      account_id = get_account_id
      course_id = create_course(account_id)["id"]
      students = create_users(account_id)
      enroll_user_in_course(students, course_id)
      install_lti_tool_to_course(course_id)
    end
  end

end