class HtmlAttachment < Attachment
  extend FriendlyId
  friendly_id :title, use: :scoped, scope: :attachable

  has_one :govspeak_content,
    autosave: true, inverse_of: :html_attachment, dependent: :destroy

  before_validation :clear_slug_if_non_english_locale

  validates :govspeak_content, presence: true

  accepts_nested_attributes_for :govspeak_content
  delegate :body, :body_html, :headers_html,
            to: :govspeak_content, allow_nil: true, prefix: true

  def rendering_app
    Whitehall::RenderingApp::GOVERNMENT_FRONTEND
  end

  # Keep a relationship between the HTML Attachment and the corresponding PDF we
  # automatically generate.
  belongs_to(
    :pdf_rendered_from_html_attachment,
    foreign_key: :pdf_rendered_from_html_attachment_id,
    class_name: 'Attachment'
  )

  def manually_numbered_headings?
    govspeak_content.manually_numbered_headings?
  end

  def accessible?
    true
  end

  def html?
    true
  end

  def pdf?
    false
  end

  def csv?
    false
  end

  # Is in OpenDocument format? (see https://en.wikipedia.org/wiki/OpenDocument)
  def opendocument?
    false
  end

  def could_contain_viruses?
    false
  end

  def content_type
    'text/html'
  end

  def name_for_link
    'HTML attachment'
  end

  def url(options = {})
    options[:preview] = id if options.delete(:preview)

    path_helper = case attachable
                  when Consultation
                    :consultation_html_attachment_path
                  else
                    :publication_html_attachment_path
                  end
    Rails.application.routes.url_helpers.send(path_helper, attachable.slug, self, options)
  end

  def extracted_text
    Govspeak::Document.new(govspeak_content_body).to_text
  end

  def should_generate_new_friendly_id?
    return false unless sluggable_locale?
    slug.nil? || attachable.nil? || !attachable.document.published?
  end

  def search_index
    super.merge({
      content: extracted_text,
    })
  end

  def deep_clone
    super.tap do |clone|
      clone.slug = slug
      clone.content_id = content_id
      clone.govspeak_content = govspeak_content.dup
    end
  end

  def readable_type
    'HTML'
  end

  def save_and_update_publishing_api
    save && Whitehall.edition_services.draft_updater(attachable).perform!
  end

  def translated_locales
    [locale || I18n.default_locale.to_s]
  end

  def generate_content_id
    previously_deleted_content_id || super
  end

private

  def sluggable_locale?
    locale.blank? or locale == "en"
  end

  def sluggable_string
    sluggable_locale? ? title : nil
  end

  def clear_slug_if_non_english_locale
    if locale_changed? and !sluggable_locale?
      self.slug = nil
    end
  end

  def previously_deleted_content_id
    @previously_deleted_content_id ||= fetch_previously_published_content_ids.last
  end

  def fetch_previously_published_content_ids
    document_id = attachable.document_id
    edition_ids = Edition.unscoped.where(document_id: document_id).pluck(:id)
    HtmlAttachment.where(
      attachable_id: edition_ids,
      title: title
    ).pluck(:content_id)
  end
end
