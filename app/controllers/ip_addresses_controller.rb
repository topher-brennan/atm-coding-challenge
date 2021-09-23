require 'httparty'

class IpAddressesController < ApplicationController
  @@cache = {}
  @@reverse_cache = {}

  def index
    # use URL params?
  end

  def show
    ip = params[:id]
    geo_response = nil
    in_cache = false

    if @@cache[ip]
      geo_response = @@cache[ip]
      in_cache = true
    else
      uri = "https://get.geojs.io/v1/ip/geo/#{ip}.json"
      geo_response = HTTParty.get(url).parsed_response
      @@cache[ip] = geo_response
    end

    city = geo_response['city']
    # region is necessary because of cases like the Portland, OR
    # and Portland, ME name collision
    region = geo_response['region']
    country = geo_response['country']
    
    if !in_cache
      @@reverse_cache[country] ||= {}
      @@reverse_cache[country][region] ||= {}
      @@reverse_cache[country][region][city] ||= []
      @@reverse_cache[country][region][city] << ip
    end

    # should we sometimes incorporate region here?
    "#{city}, #{country}"
  end
end
