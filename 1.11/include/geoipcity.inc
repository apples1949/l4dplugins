#if defined _geoipcity_included
  #endinput
#endif
#define _geoipcity_included

/**
 * @section IP addresses can contain ports, the ports will be stripped out.
 */

/**
 * Gets the GeoIP record from an IP address.
 *
 * @param ip				Ip to determine the country code.
 * @param city				Destination string buffer to store the city name. (45 characters max)
 * @param region			The region/province/state name. (45 characters max)
 * @param country_name		The country name. (45 characters max)
 * @param country_code		The two character country code. (US, CA, etc)
 * @param country_code3		The three character country code. (USA, CAN, etc)
 * @return					True on success, false if no record found.
 */
native bool:GeoipGetRecord(const String:ip[], String:city[45], String:region[45], String:country_name[45], String:country_code[3], String:country_code3[4]);

/**
 * @endsection
 */

/**
 * Do not edit below this line!
 */
public Extension:__ext_geoipcity = 
{
	name = "GeoIPCity",
	file = "geoipcity.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_EXTENSIONS
public __ext_geoipcity_SetNTVOptional()
{
	MarkNativeAsOptional("GeoipGetRecord");
}
#endif
