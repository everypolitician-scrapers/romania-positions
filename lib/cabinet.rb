# TODO: extending Scraped::Scraper with ability to add Strategies
class Scraped::Request::Strategy::LiveRequest
  require 'rest-client'

  def url
    SPARQL_URL % CGI.escape(QUERY % @url)
  end

  private

  def sparql(query)
    result = RestClient.get WIKIDATA_SPARQL_URL, accept: 'text/csv', params: { query: query }
    CSV.parse(result, headers: true, header_converters: :symbol)
  rescue RestClient::Exception => e
    raise "Wikidata query #{query} failed: #{e.message}"
  end

  SPARQL_URL = 'https://query.wikidata.org/sparql?format=json&query=%s'

  QUERY = <<~SPARQL
    SELECT DISTINCT ?ps ?item ?itemLabel ?minister ?ministerLabel ?ordinal ?start ?end ?cabinet ?cabinetLabel
    WHERE {
      ?item p:P39/ps:P39/wdt:P279* wd:%s .
      ?item p:P39 ?ps .
      ?ps ps:P39 ?minister .
      ?minister wdt:P279* wd:Q83307 .
      OPTIONAL { ?ps pq:P1545 ?ordinal }
      OPTIONAL { ?ps pq:P580  ?start }
      OPTIONAL { ?ps pq:P582  ?end }
      OPTIONAL { ?ps pq:P5054 ?cabinet }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
    }
  SPARQL
end

class CabinetScraper < Scraped::JSON
  field :memberships do
    json[:results][:bindings].map { |result| fragment(result => Membership).to_h }
  end

  class Membership < Scraped::JSON
    field :id do
      json.dig(:item, :value).to_s.split('/').last
    end

    field :name do
      json.dig(:itemLabel, :value)
    end

    field :position_id do
      json.dig(:ps, :value).to_s.split('/').last
    end

    field :position do
      json.dig(:minister, :value).to_s.split('/').last
    end

    field :label do
      json.dig(:ministerLabel, :value)
    end

    field :start_date do
      json.dig(:start, :value).to_s[0..9]
    end

    field :end_date do
      json.dig(:end, :value).to_s[0..9]
    end

    field :ordinal do
      json.dig(:ordinal, :value).to_i
    end
  end
end
