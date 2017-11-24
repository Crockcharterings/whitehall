class TaxonomyTagForm
  include ActiveModel::Model

  attr_accessor :selected_taxons, :all_taxons, :content_id, :previous_version

  def self.load(content_id)
    begin
      content_item = Services.publishing_api.get_links(content_id)

      selected_taxons = content_item["links"]["taxons"] || []
      previous_version = content_item["version"] || 0
    rescue GdsApi::HTTPNotFound
      # TODO: This is a workaround, because Publishing API
      # returns 404 when the document exists but there are no links.
      # This can be removed when that changes.
      selected_taxons = []
      previous_version = 0
    end

    new(
      selected_taxons: selected_taxons,
      content_id: content_id,
      previous_version: previous_version
    )
  end

  def published_taxons
    @_published_taxons ||= begin
      taxons = []
      govuk_taxonomy.children.each do |branch|
        matched_taxons = filter_against_taxonomy_branch(selected_taxons, branch, [])
        taxons.concat(matched_taxons) if matched_taxons.any?
      end
      taxons
    end
  end

  def visible_draft_taxons
    @_draft_taxons ||= begin
      taxons = []
      govuk_taxonomy.draft_child_taxons.each do |branch|
        matched_taxons = filter_against_taxonomy_branch(selected_taxons, branch, [])
        taxons.concat(matched_taxons) if matched_taxons.any?
      end
      taxons
    end
  end

  def invisible_draft_taxons
    selected_taxons - published_taxons - visible_draft_taxons
  end

  def filter_against_taxonomy_branch(selected_taxons_content_ids, taxon, matched_taxons)
    if selected_taxons_content_ids.include?(taxon.content_id)
      matched_taxons << taxon.content_id
    end

    taxon.children.each do |child_taxon_branch|
      filter_against_taxonomy_branch(selected_taxons, child_taxon_branch, matched_taxons)
    end

    return matched_taxons
  end

  def govuk_taxonomy
    @_taxonomy ||= Taxonomy::GovukTaxonomy.new
  end

  def publish!
    Services
      .publishing_api
      .patch_links(
        content_id,
        links: { taxons: most_specific_taxons },
        previous_version: previous_version
      )
  end

  # Ignore any taxons that already have a more specific taxon selected
  def most_specific_taxons
    all_taxons.each_with_object([]) do |taxon, list_of_taxons|
      content_ids = taxon.descendants.map(&:content_id)

      any_descendants_selected = selected_taxons.any? do |selected_taxon|
        content_ids.include?(selected_taxon)
      end

      unless any_descendants_selected
        content_id = taxon.content_id
        list_of_taxons << content_id if selected_taxons.include?(content_id)
      end
    end
  end
end
