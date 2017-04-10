When(/^I make unsaved changes to the news article$/) do
  @news_article = NewsArticle.last
  visit edit_admin_news_article_path(@news_article)
  fill_in 'Title', with: 'An unsaved change'
end

When(/^I attempt to visit the attachments page$/) do
  first(:link, 'Attachments').click
end

Then(/^I should stay on the edit screen for the news article$/) do
  assert_path edit_admin_news_article_path(@news_article)
end

When(/^I save my changes$/) do
  click_on 'Save and continue editing'
end

Then(/^I can visit the attachments page$/) do
  first(:link, 'Attachments').click
  assert_path admin_edition_attachments_path(@news_article)
end

When /^the (?:attachment|image)s? (?:has|have) been virus\-checked$/ do
  FileUtils.cp_r(Whitehall.incoming_uploads_root + '/.', Whitehall.clean_uploads_root + "/")
  FileUtils.rm_rf(Whitehall.incoming_uploads_root)
  FileUtils.mkdir(Whitehall.incoming_uploads_root)
end

Then /^the image will be quarantined for virus checking$/ do
  assert_final_path(person_image_path, "thumbnail-placeholder.png")
end

Then /^the virus checked image will be available for viewing$/ do
  assert_final_path(person_image_path, person_image_path)
end

When(/^I start editing the attachments from the .*? page$/) do
  click_on 'Modify attachments'
end

When(/^I upload a file attachment with the title "(.*?)" and the file "(.*?)"$/) do |title, fixture_file_name|
  click_on 'Upload new file attachment'
  fill_in 'Title', with: title
  attach_file 'File', Rails.root + "test/fixtures/#{fixture_file_name}"
  click_on 'Save'
end

When(/^I upload an html attachment with the title "(.*?)" and the body "(.*?)"$/) do |title, body|
  click_on 'Add new HTML attachment'
  fill_in 'Title', with: title
  fill_in 'Body', with: body
  check 'Manually numbered headings'
  click_on 'Save'
end

When(/^I add an external attachment with the title "(.*?)" and the URL "(.*?)"$/) do |title, url|
  create_external_attachment(url, title)
end

When(/^I try and upload an attachment but there are validation errors$/) do
  ensure_path admin_publication_path(Publication.last)
  click_on 'Modify attachments'
  click_on 'Upload new file attachment'
  attach_file 'File', Rails.root + "test/fixtures/greenpaper.pdf"
  click_on 'Save'
end

Then(/^I should be able to submit the attachment without re\-uploading the file$/) do
  fill_in 'Title', with: 'Title that was missing before'
  click_on 'Save'

  assert_equal 2, Publication.last.attachments.count
  assert_equal 'Title that was missing before', Publication.last.attachments.last.title
end

Then(/^the .* "(.*?)" should have (\d+) attachments$/) do |title, expected_number_of_attachments|
  assert_equal expected_number_of_attachments.to_i, Edition.find_by(title: title).attachments.count
end

When(/^I set the order of attachments to:$/) do |attachment_order|
  attachment_order.hashes.each do |attachment_info|
    attachment = Attachment.find_by(title: attachment_info[:title])
    fill_in "ordering[#{attachment.id}]", with: attachment_info[:order]
  end
  click_on 'Save attachment order'
end

Then(/^the attachments should be in the following order:$/) do |attachment_list|

  attachment_ids = page.all('.existing-attachments > li').map {|element| element[:id] }

  attachment_list.hashes.each_with_index do |attachment_info, index|
    attachment = Attachment.find_by(title: attachment_info[:title])

    assert_equal "attachment_#{attachment.id}", attachment_ids[index]
  end
end

Given(/^a draft closed consultation "(.*?)" with an outcome exists$/) do |title|
  create(:consultation_with_outcome, :draft, title: title)
end

When(/^I go to the outcome for the consultation "(.*?)"$/) do |title|
  consultation = Consultation.find_by(title: title)
  visit admin_consultation_outcome_path(consultation)
end

Then(/^the outcome for the consultation should have the attachment "(.*?)"$/) do |attachment_title|
  assert page.has_no_selector?(".flash.alert")
  assert page.has_content?(attachment_title)
end

Given(/^the publication "(.*?)" has an html attachment "(.*?)" with the body "(.*?)"$/) do |publication_title, attachment_title, attachment_body|
  publication = Publication.find_by(title: publication_title)
  create :html_attachment, attachable: publication, title: attachment_title, body: attachment_body
end

When(/^I preview the attachment "(.*?)"$/) do |attachment_title|
  click_on attachment_title
end

Then(/^I should see the html attachment body "(.*?)"$/) do |attachment_body|
  assert page.has_content?(attachment_body)
end

When(/^I upload an html attachment with the title "(.*?)" and the isbn "(.*?)" and the contact address "(.*?)"$/) do |title, isbn, contact_address|
  click_on "Add new HTML attachment"
  fill_in "Title", with: title
  fill_in "ISBN (web version)", with: isbn
  fill_in "Organisation's Contact Details", with: contact_address
  fill_in "Body", with: "Body"
  check "Manually numbered headings"
  click_on "Save"
end

When(/^I create an html attachment with the title "(.*?)" that should be rendered as a PDF$/) do |title|
  click_on "Add new HTML attachment"
  fill_in "Title", with: title
  fill_in "Body", with: "Body"
  check "Should we render a PDF for this HTML attachment?"
  click_on "Save"
end

Given(/^I have a mock HTML attachment at "(.*?)"$/) do |path|
  stub_attachment_in_content_store("/government/publication#{path}")
  stub_request(:get, %r(/government/publications#{path}))
    .to_return(body: '<h1>Some HTML</h1>')
end

When(/^I publish the draft edition for publication "(.*?)"$/) do |publication_title|
  publication = Publication.find_by title: publication_title
  publication.update!(state: 'published', major_change_published_at: Date.today)
end

Then /^previewing the html attachment "(.*?)" in print mode includes the contact address "(.*?)" and the isbn "(.*?)"$/ do |attachment_title, contact_address, isbn|
  html_attachment = HtmlAttachment.find_by title: attachment_title
  publication = html_attachment.attachable
  visit publication_html_attachment_path publication_id: publication.slug, id: html_attachment.slug, medium: "print"
  assert page.has_content? contact_address
  assert page.has_content? isbn
end

Then(/^I should eventually see a PDF attachment for "(.*?)"$/) do |title|
  begin
    Timeout::timeout(10) do
      attachments = []
      until attachments.count == 2
        page.driver.visit(page.driver.current_url)

        attachments = page.all('#attachments tr').map do |row|
          columns = row.all('td').map(&:text)
          {
            title: columns[0],
            filename: columns[1],
          }
        end
        # Remove header row
        attachments.slice!(0)
      end

      assert attachments.any? do |attachment|
        title == attachment.title &&
          /^#{title.parameterize}.*\.pdf$/ =~ attachment.filename
      end
    end
  rescue Timeout::Error
    raise 'Timed out waiting for the PDF attachment to be generated by the worker'
  end
end
