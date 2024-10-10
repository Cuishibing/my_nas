package cui.shibing.core;

import java.util.HashMap;

import org.apache.commons.lang3.StringUtils;

public class UriParser {
    /**
     * UriInfo
     */
    public static record UriInfo(String modelName, String eventName, HashMap<String, String> queryParams) {
    }

    public static UriInfo parse(String uri) {
        if (StringUtils.isBlank(uri)) {
            return null;
        }

        if (uri.startsWith("/")) {
            uri = uri.substring(1);
        }

        var qIndex = uri.indexOf("?");
        var queryParams = new HashMap<String, String>();
        if (qIndex >= 0) {
            var queryString = uri.substring(qIndex + 1);
            uri = uri.substring(0, qIndex);
            var queryParamsArray = queryString.split("&");
            for (var queryParamPair : queryParamsArray) {
                if (queryParamPair.contains("=")) {
                    var paramKeyAndValue = queryParamPair.split("=");
                    if (paramKeyAndValue.length != 2) {
                        continue;
                    }
                    queryParams.put(paramKeyAndValue[0], paramKeyAndValue[1]);
                }
            }
        }

        var uriArray = uri.split("/");
        if (uriArray.length != 3) {
            return null;
        }
        return new UriInfo(uriArray[1], uriArray[2], queryParams);
    }
}
