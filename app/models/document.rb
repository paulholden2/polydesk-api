class Document < ApplicationRecord
  # Ignore Shrine data column so versions aren't triggered when files move
  # from cache.
  has_paper_trail ignore: [:discarded_at, :content_data]

  include Rails.application.routes.url_helpers
  include Polydesk::VerifyDocument
  include Discard::Model

  include DocumentContentUploader::Attachment.new(:content)
  validates :content, presence: true
  validates :name, presence: true, format: {
    # Allow alphanumerals, spaces, and _ . - ( ) [ ]
    # The first character may not be a space, and the last must not be a space or period.
    with: /\A[A-Za-z0-9\-\(\)\[\]'_\.][A-Za-z0-9 \-\(\)\[\]'_\.]*[A-Za-z0-9\-\(\)\[\]'_]\z/,
    message: 'may only contain alphanumerals, spaces, or the following: _ . - ( ) [ ] and may not start with a space or end with either a space or .'
  }
  validates :name, uniqueness: { scope: [:folder_id, :unique_enforcer] },
                   unless: Proc.new { |doc| doc.unique_enforcer.nil? }
  belongs_to :folder, optional: true

  def related_folder_url
    document_folder_url(id: self.id, identifier: Apartment::Tenant.current)
  end

  before_validation :default_folder, :set_document_name, :enumerate_name
  before_save :save_content_attributes, :within_storage_limit

  attr_accessor :skip_background_upload

  after_save do
    if self.skip_background_upload
      self.skip_background_upload = false
      self.content_attacher.promote
      self.save
    end
  end

  # Destroy this record's associated versions
  before_destroy do
    self.versions.destroy_all
  end

  def default_folder
    self.folder_id ||= 0
  end

  def set_document_name
    if self.content
      self.name = self.content.metadata['filename'] if self.name.blank? || self.name.nil?
    end
  end

  # TODO: Better extension detection. Would be nice to handle "combination"
  # extensions, e.g. .html.erb
  # --------------------------------------------------------------------------
  # Enumerate documents if there is one with an existing name
  def enumerate_name
    # Only enumerate if the name has changed
    if self.name_changed?
      ActiveRecord::Base.transaction do
        desired_name = self.name
        ext_name = File.extname(desired_name)
        base_name = File.basename(desired_name, ext_name)
        existing = Document.kept.find_by(folder_id: self.folder_id, name: desired_name)
        # Only enumerate if there's a naming conflict
        if existing
          # Look for any potential conflicts (but only undiscarded documents)
          conflicts = Document.kept.where(folder_id: self.folder_id)
                                   .where(['name LIKE ?', "#{base_name}%"])
          if conflicts.empty?
            # If no conflicts, only the exact duplicate name is a conflict,
            # so just add (1) and call it done.
            self.name = "#{base_name} (1)#{ext_name}"
          else
            # Otherwise, there may be existing enumerated files
            r = /#{base_name} \((\d+)\)#{ext_name}/
            regexp = Regexp.new(r)
            # Find any potential conflicts with the exact name, but enumerated
            numbers = conflicts.map { |document|
              match = regexp.match(document.name)
              # If there's a match. get the enumeration value
              match.captures.first.to_i unless match.nil?
            }
            # Filter out nils (the name wasn't an enumeration of the desired
            # document name, but just a similar name)
            numbers.reject! { |n| n.nil? }
            # No enumerated names? Go with default of (1)
            if numbers.empty?
              self.name = "#{base_name} (1)#{ext_name}"
            else
              # Get next value (no need to complicate it with filling gaps)
              numbers.sort_by! { |n| -n }
              self.name = "#{base_name} (#{numbers.first + 1})#{ext_name}"
            end
          end
        end
      end
    end
  end

  def save_content_attributes
    if content
      self.content_type = content.metadata['mime_type']
      self.file_size = content.metadata['size']
    end
  end

  def url
    document_url(id: self.id, identifier: Apartment::Tenant.current)
  end
end
