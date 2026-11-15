// CloudFront viewer-request function (runtime cloudfront-js-2.0), attached in
// ../cloudfront.tf. Terraform renders this file with templatefile(), which
// substitutes $${primary_domain}, so don't use JavaScript template literals.

var PRIMARY_DOMAIN = "${primary_domain}";

function handler(event) {
  var request = event.request;
  var host = request.headers.host ? request.headers.host.value.toLowerCase() : "";
  var uri = request.uri;

  // Hugo publishes each page as <path>/index.html, so give every page one URL,
  // with a trailing slash: /about -> /about/
  var lastSegment = uri.substring(uri.lastIndexOf("/") + 1);
  var path = lastSegment !== "" && lastSegment.indexOf(".") === -1 ? uri + "/" : uri;

  // www. and the redirect domains all land on the primary domain.
  if (host !== PRIMARY_DOMAIN || path !== uri) {
    return {
      statusCode: 301,
      statusDescription: "Moved Permanently",
      headers: {
        location: { value: "https://" + PRIMARY_DOMAIN + path + queryString(request.querystring) },
      },
    };
  }

  if (uri.endsWith("/")) {
    request.uri = uri + "index.html";
  }
  return request;
}

// Rebuilds the query string from CloudFront's parsed form, including repeated
// parameters (multiValue).
function queryString(params) {
  var parts = [];
  for (var name in params) {
    var values = params[name].multiValue || [params[name]];
    for (var i = 0; i < values.length; i++) {
      parts.push(values[i].value === "" ? name : name + "=" + values[i].value);
    }
  }
  return parts.length > 0 ? "?" + parts.join("&") : "";
}
