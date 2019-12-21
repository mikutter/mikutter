# -*- coding: utf-8 -*-

Plugin.create(:file_path) do

  # Unix local file path
  filter_uri_filter do |uri|
    if uri.is_a?(String) && uri.start_with?('/')
      [Addressable::URI.new(scheme: 'file', path: uri)]
    else
      [uri]
    end
  end

end
