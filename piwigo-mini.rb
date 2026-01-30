# A simple interface to piwigo

# The full API gem has been unmaintained for years and the way it's written
# is very brittle and will break with any API change on the server end, so
# I don't want to deal with that. This is read-only and just lets you access
# albums/categories and images.

require 'uri'
require 'net/http'
require 'json'

module PiwigoMini
  class ApiError < StandardError
  end

  class Api
    def initialize(uri)
      @uri = URI("#{uri}/ws.php?format=json")
    end

    def request(method, params = {})
      params['method'] = method
      result = Net::HTTP.post_form(@uri, params)
      raise ApiError, result.message unless result.code == "200"

      JSON.parse(result.body)['result']
    end

    def albums
      albums = []
      self.request('pwg.categories.getList')['categories'].each do |album|
        albums << Album.new(api: self, id: album['id'], data: album)
      end

      albums
    end

    def album(id)
      self.request('pwg.categories.getList', {cat_id: id})['categories'].each do |album|
        next unless album['id'] == id
        return Album.new(api: self, id: album['id'], data: album)
      end

      return nil
    end

    def image(id)
      image = self.request('pwg.images.getInfo', {image_id: id})
      return Image.new(api: self, id: image['id'], data: image)
    end
  end

  class ApiItem
    def initialize(api:, id:, data:)
      @api = api
      @id = id
      @data = data
    end

    def method_missing(key)
      super unless @data.include? key.to_s

      @data[key.to_s]
    end
  end

  class Album < ApiItem
    def images
      images = []
      @api.request('pwg.categories.getImages', {cat_id: @id})['images'].each do |image|
        images << Image.new(api: @api, id: image['id'], data: image)
      end

      images
    end

    def sub_albums
      albums = []
      @api.request('pwg.categories.getList', {cat_id: @id})['categories'].each do |album|
        albums << Album.new(api: @api, id: album['id'], data: album)
      end

      albums
    end
  end

  class Image < ApiItem
    def image_data
      image_url = URI(@data['element_url'])
      result = Net::HTTP.get_response(image_url)
      raise ApiError, result.message unless result.code == "200"

      result.body
    end
  end
end
