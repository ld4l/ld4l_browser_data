=begin
--------------------------------------------------------------------------------

Process one URI, fetching the relevant triples from the triple-store, recording
stats, and writing an N3 file.

--------------------------------------------------------------------------------
=end
require "ruby-xxhash"
require "ld4l_browser_data/utilities/uri_processor_helper"

module Ld4lBrowserData
  module GenerateLod
    class LinkedDataCreator
      class UriProcessor
        include Utilities::UriProcessorHelper
        include Utilities::TripleStoreUser

        QUERY_OUTGOING = <<-END
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
        CONSTRUCT {
          ?uri ?p ?o .
          ?o a ?type .
          ?o rdfs:label ?label . 
          ?o skos:prefLabel ?prefLabel . 
        }
        WHERE { 
          GRAPH ?g {
            ?uri ?p ?o . 
            OPTIONAL {
              ?o a ?type .
            } 
            OPTIONAL {
              ?o rdfs:label ?label . 
            } 
            OPTIONAL {
              ?o skos:prefLabel ?prefLabel . 
            }
          } 
        }
        END

        QUERY_INCOMING = <<-END
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
        CONSTRUCT {
          ?s ?p ?uri .
          ?s a ?type . 
          ?s rdfs:label ?label . 
          ?s skos:prefLabel ?prefLabel . 
        }
        WHERE { 
          GRAPH ?g {
            ?s ?p ?uri .
            OPTIONAL {
              ?s a ?type . 
            } 
            OPTIONAL {
              ?s rdfs:label ?label . 
            } 
            OPTIONAL {
              ?s skos:prefLabel ?prefLabel . 
            }
          } 
        }
        END
        #
        def initialize(ts, files, report, uri)
          @ts = ts
          @files = files
          @report = report
          @uri = uri
          @digest = Digest::XXHash.new(64)
        end

        def build_the_graph
          @graph = RDF::Graph.new
          @graph << QueryRunner.new(QUERY_OUTGOING).bind_graph('g', @uri).bind_uri('uri', @uri).construct(@ts)
          @graph << QueryRunner.new(QUERY_INCOMING).bind_graph('g', @uri).bind_uri('uri', @uri).construct(@ts)
        end

        def write_it_out
          @content = RDF::Writer.for(file_extension: "ttl").buffer do |writer|
            writer << @graph
          end
          @files.write(@uri, @content)
        end

        def run()
          begin
            if (@files.acceptable?(@uri))
              build_the_graph
              write_it_out
              @report.good_uri(@uri, @graph, @content)
              error_monitor.good
            else
              @report.bad_uri(@uri)
              error_monitor.bad
            end
          rescue
            @report.failed_uri(@uri, $!)
            error_monitor.failed
          end
        end
      end
    end
  end
end