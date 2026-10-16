# /sitemap.xml for the public site: states, elections, 2026 races and every
# person page (~47k URLs, under the 50k-per-file limit). Built at most once a
# day per dyno. Note robots.txt still disallows crawling; whether to open the
# site to search engines is a pending team decision (overhaul plan).
class SitemapsController < PublicController
  def show
    xml = Rails.cache.fetch('sitemap/v1', expires_in: 1.day) { build }
    render xml: xml
  end

  private

  def build
    base = request.base_url
    urls = []
    urls << [root_url, nil] << [elections_url, nil] << [states_url, nil] << [people_url, nil]
    State.order(:abbreviation).pluck(:abbreviation).each { |abbr| urls << [state_url(abbr), nil] }
    Election.order(:id).pluck(:id, :updated_at).each { |id, at| urls << [election_url(id), at] }
    Contest.joins(:ballot).where(ballots: { year: ElectionsController::YEAR })
           .order(:id).pluck(:id, :updated_at).each { |id, at| urls << [contest_url(id), at] }
    Person.select(:id, :first_name, :middle_name, :last_name, :suffix, :updated_at).find_each do |p|
      urls << ["#{base}/people/#{p.to_param}", p.updated_at]
    end

    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |x|
      x.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') do
        urls.each do |loc, at|
          x.url do
            x.loc loc
            x.lastmod at.to_date.iso8601 if at
          end
        end
      end
    end
    builder.to_xml
  end
end
