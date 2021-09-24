require 'httparty'

class IpAddressesController < ApplicationController
  @@cache = {}
  @@reverse_cache = {}

  # I included regions in this design because in the US, at least, it can be important to distinguish between cities with
  # the same name in different states. I also decided to require that if a city is provided, a region must be provided, and
  # if a region is provided, a country must be provided.

  # I don't expect anyone will want to query for all IP addresses associated with cities named "London", regardless of whether 
  # the city is in the UK, in France, or is one of the ten locations in the US named "London". However, I realize this might 
  # have downsides if at some point the Geo API returned a record with a city but not a region. Depending on who is using
  # the API, that requirement might also cause problems if a user didn't know the official name of the region (e.g. in smaller
  # countries not normally divided into regions, or cities often thought of as not being a part of any region, such as
  # Washington, DC).

  # The most straightforward way to support queries with any combination of city, region, and/or country would be to store 
  # results of calls to the Geo API in a relational database. If for some reason it was important to have a purely in-memory
  # cache, a more complicated in-memory caching scheme could be used, but if possible it would be better to avoid complicating
  # the code in that way.

  def index
    city = params[:city]
    region = params[:region]
    country = params[:country]

    ip_addresses = nil

    if country && region && city
      ip_addresses = @@reverse_cache.dig(country, region, city) || []
    elsif city
      render json: {
        error: "If a city is provided, a country and region must also be provided.",
        status: 400
      }, status: 400
      return
    elsif country && region
      ip_addresses = cache_flatten(@@reverse_cache.dig(country, region))
    elsif region
      render json: {
        error: "If a region is provided, a country must also be provided.",
        status: 400
      }, status: 400
      return
    elsif country
      ip_addresses = cache_flatten(@@reverse_cache[country])
    else
      ip_addresses = cache_flatten(@@reverse_cache)
    end

    render :json => {"ip_addresses" => ip_addresses}
  end

  def cache_flatten(dict_or_hash)
    if dict_or_hash.class == Array
      return dict_or_hash
    elsif dict_or_hash.class == Hash
      return dict_or_hash.map do |k, v|
        cache_flatten(v)
      end.reduce([], :concat)
    else
      raise ArgumentError.new("Argument must be an Array or Hash")
    end
  end

  def show
    ip = params[:id]
    geo_response = nil
    in_cache = false

    if @@cache[ip]
      geo_response = @@cache[ip]
      in_cache = true
    else
      url = "https://get.geojs.io/v1/ip/geo/#{ip}.json"
      geo_response = HTTParty.get(url).parsed_response
      @@cache[ip] = geo_response
    end

    city = geo_response['city']
    region = geo_response['region']
    country = geo_response['country']
    
    if !in_cache
      @@reverse_cache[country] ||= {}
      @@reverse_cache[country][region] ||= {}
      @@reverse_cache[country][region][city] ||= []
      @@reverse_cache[country][region][city] << ip
    end

    render :json => { "city" => city, "region" => region,  "country" => country }
  end
end
