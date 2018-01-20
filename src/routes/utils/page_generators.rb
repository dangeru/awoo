############################################
# => page_generators.rb - Helper functions for turning a page number into a url to access that page
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#

require 'erb'
Default_page_generator = ->(board, request, params, index) do
  "/" + board + "/?page=" + index.to_s
end
Archive_page_generator = ->(board, request, params, index) do
  if board == "all" then
    return "/archive/?page=" + index.to_s
  end
  "/archive/" + board + "/?page=" + index.to_s
end
Search_page_generator = ->(board, request, params, index) do
  "/search_results/?page=" + index.to_s +
    "&search_text=" + ERB::Util.url_encode(params[:search_text]) +
    "&board_select=" + ERB::Util.url_encode(params[:board_select])
end
Search_page_generator_advanced = ->(board, request, params, index) do
  "/advanced_search_results/?page=" + index.to_s +
    "&search_text=" + ERB::Util.url_encode(params[:search_text]) +
    "&board_select=" + ERB::Util.url_encode(params[:board_select])
end
