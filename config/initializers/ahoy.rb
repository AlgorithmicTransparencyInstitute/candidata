class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = false

# Cookieless visit tracking (anonymity sets) with the last IP octet masked, so
# the first-party visit log needs no consent and stores no full IPs. The privacy
# banner (shared/_cookie_consent) describes exactly this.
Ahoy.cookies = :none
Ahoy.mask_ips = true
