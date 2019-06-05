class FormSubmissionRealizer
  include JSONAPI::Realizer::Resource
  type :form_submissions, class_name: 'FormSubmission', adapter: :active_record
  has :data
  has_one :form, class_name: 'FormRealizer'
  has_one :submitter, class_name: 'UserRealizer'
end