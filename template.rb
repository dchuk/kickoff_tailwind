# Template Name: Kickoff - Tailwind CSS
# Instructions: $ rails new myapp -d <postgresql, mysql, sqlite3> -j esbuild -m template.rb

def source_paths
  [__dir__]
end

def add_gems
  gem 'devise', '~> 4.8'
  gem 'friendly_id', '~> 5.4', '>= 5.4.2'
  gem 'name_of_person', '~> 1.1', '>= 1.1.1'
  # gem "pay", "~> 3.0" # https://github.com/pay-rails/
  # gem "stripe", ">= 2.8", "< 6.0" # I prefer Stripe but you can opt for braintree or paddle too. https://github.com/pay-rails/pay/blob/master/docs/1_installation.md#gemfile
  gem 'image_processing', '~> 1.2'
  gem 'cssbundling-rails'
  gem 'good_job'
  gem 'view_component'
end

def add_css_bundling
  rails_command 'css:install:tailwind'
  # remove tailwind config that gets installed and swap for new one
  remove_file 'tailwind.config.js'
end

# source: https://railsbytes.com/public/templates/V4Ys1d
def setup_uuids
  model_name = generate(:migration, 'enable_uuid')

  command = <<-CODE
  MIGRATION_FILE=$(find . -name "*enable_uuid.rb") && awk -v q=\\' '1;/change/{ print "   enable_extension" q "pgcrypto" q}' $MIGRATION_FILE > enable_uuid.rb && mv enable_uuid.rb $MIGRATION_FILE
  CODE

  inside('db/migrate') do
    run(command)
  end

  initializer 'generators.rb', <<-CODE
  Rails.application.config.generators do |g|
    g.orm :active_record, primary_key_type: :uuid
  end
  CODE
end

def add_storage_and_rich_text
  rails_command 'active_storage:install'
  rails_command 'action_text:install'
end

def add_users
  # Install Devise
  generate 'devise:install'

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  route "root to: 'home#index'"

  # Create Devise User
  generate :devise, 'User', 'first_name', 'last_name'

  rails_command 'db:migrate'

  # set admin boolean to false by default
  # in_root do
  #   migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
  # end

  # name_of_person gem
  append_to_file('app/models/user.rb', "\nhas_person_name\n", after: 'class User < ApplicationRecord')
end

def add_good_job
  generate 'good_job:install'
  rails_command 'db:migrate'
  application 'config.active_job.queue_adapter = :good_job'

  # get dashboard working https://github.com/bensheldon/good_job#dashboard
  inject_into_file 'config/application.rb', after: 'require "rails/all"' do
    "\nrequire 'good_job/engine'"
  end
  route "mount GoodJob::Engine => 'good_job'"
end

def add_view_components
  # configures sidecar assets and automatic stimulus controller generation
  application 'config.view_component.generate_sidecar = true'
  application 'config.view_component.generate_stimulus_controller = true'

  # Source: https://github.com/github/view_component/issues/1064#issuecomment-974733856
  directory 'lib', force: true
  inject_into_file 'app/javascript/application.js', after: 'import "@rails/actiontext"' do
    "\nimport '../components';"
  end

  directory 'app/components', force: true
  rails_command 'stimulus:manifest:update'
end

def copy_templates
  directory 'app', force: true
end

def add_friendly_id
  generate 'friendly_id'
end

def add_pay
  rails_command 'pay:install:migrations'

  # add pay_customer to user
  # https://github.com/pay-rails/pay/blob/master/docs/1_installation.md#models
  # append_to_file("app/models/user.rb", "\npay_customer\n", after: "class User < ApplicationRecord")
end

def add_tailwind_plugins
  run 'yarn add -D @tailwindcss/typography @tailwindcss/forms @tailwindcss/aspect-ratio @tailwindcss/line-clamp'
  copy_file 'tailwind.config.js'
end

# Main setup
source_paths

add_gems

after_bundle do
  rails_command 'db:reset'

  add_css_bundling
  setup_uuids
  add_storage_and_rich_text
  add_tailwind_plugins
  add_users
  add_good_job
  add_view_components
  copy_templates
  add_friendly_id
  # add_pay

  # Migrate
  rails_command 'db:migrate'

  git :init
  git add: '.'
  git commit: %( -m "Initial commit" )

  say ''
  say 'Your app successfully created!'
end
