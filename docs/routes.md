# Flight Desktop Server - Desktop API

Manage interactive VNC sessions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [BCP 14](https://tools.ietf.org/html/bcp14) \[[RFC2119](https://tools.ietf.org/html/rfc2119)\] \[[RFC8174](https://tools.ietf.org/html/rfc8174)\] when, and only when, they appear in all capitals, as shown here.

All errors conform to the [JSON:API error specification](https://jsonapi.org/format/#errors).

## Headers and Authorization

All requests SHOULD set the following headers:

```
# All Routes
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

# NON GET/DELETE Routes
Content-Type: application/json
```

The `Authorization` header is a base64 encoded `<username>:<password>` tuple. The `username` and `password` SHOULD match the underlining system according to the [pam sshd config](https://www.pks.mpg.de/~mueller/docs/suse10.1/suselinux-manual_en/manual/sec.pam.struc.format.html). This MAY be changed to any other `pam` config.

The following error SHALL be returned if the `pam` authentication check fails:

```
HTTP/2 401 Unauthorized
{
  "errors": [
    {
      "status": "401",
      "code": "Unauthorized"
    }
  ]
}
```

Commands can not be executed as `root` to mitigate against security issues. The following error will be raised when attempting to preform any action as `root`:

```
HTTP/2 403 Forbidden
{
  "errors": [
    {
      "status": "403",
      "code": "Root Forbidden"
    }
  ]
}
```

The `POST` request also needs to specify the `Content-Type` otherwise the following error will be raised:

```
HTTP/2 415 Unsupported Media Type
Content-Type: application/json

{
  "errors": [{
    "status": "415",
    "code": "Unsupported Media Type"
  }]
}
```

## Sessions

### ID

The `id` for a `sessions` MUST conform to the `UUID` format according to [RFC4122](https://tools.ietf.org/html/rfc4122#section-3).

*BUG NOTICE:* There is a known issue where the first "portion" of the UUID can be used as an `id`. Its behaviour is undetermined and SHALL be removed in future releases. The full UUID MUST always be used as the `id`.

### GET Index

Return a list of all currently running desktop sessions for the identified user. The `data` attribute MAY be empty. The `include=screenshot` query parameter SHOULD trigger the base64 encoded screenshot to be returned for each session resource.

```
GET /sessions
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

HTTP/2 200 OK
{
  "data": [
    <session-resource-object>,
    ...
  ]
}
```

#### Other Responses

To retrieve the screenshot for each session:

```
GET /sessions?include=screenshot
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

HTTP/2 200 OK
{
  "data": [
    <session-resource-object-with-screenshot>,
    ...
  ]
}
```

### GET Show

Returns an instance of a running session. The `include=screenshot` query parameter SHOULD trigger the base64 encoded screenshot to be returned with the request.

```
GET /sessions/:id
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

HTTP/2 200 OK
{
  "id": "<UUID>",
  "desktop": "<desktop-type>",
  "ip": "<ip>,
  "hostname": "<hostname>",
  "port": <web-sockify-port>,
  "password": "<vnc-password>",
  "state": "<Active|BROKEN|...>",
  "created_at": "<time-rfc339>",
  "last_accessed_at": "<None|time-rfc3339>"
}

# When the screenshot is included

GET /sessions/:id?include=screenshot
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

HTTP/2 200 OK
{
  ... as above ...,
  "screenshot": "<Base64 encoded sceenshot>"
}
```

#### Response Attributes

*desktop*

The desktop type of the session

Type: String (See: `flight desktop avail`)

*ip*

The "host IP" for the session.

Type: String

*hostname*

The "hostname" for the session.

Type: String

*port*

The external "websockify port" for the session.

Type: String

*password*

The "vnc password" for the session.

Type: String

*state*

The "state" the session is currently in

Type: String

*created_at*

The time the session was created

Type: [String - RFC3339 Timestamp](https://tools.ietf.org/html/rfc3339)

*last_accessed_at*

The time the session was last accessed. This field MAY be None if the session has not yet be accessed.

Type: None | [String - RFC3339 Timestamp](https://tools.ietf.org/html/rfc3339)

*screenshot*

Returns the base64 encoded screenshot. The `included=snapshot` query parameter is REQUIRED for this attribute to be returned. It MUST return None when the snapshot does not exist.

Type: None | String - image/png;base64

#### Other Responses

```
HTTP/2 404 Not Found
Content-Type: application/json

{
  "errors": [
    {
      "status": "404",
      "code": "Not Found",
      "detail": "Could not find 'session': <missing-id>"
    }
  ]
}
```

### POST Create

Start a new vnc session with the given `desktop` type.

*BUG NOTICE*: The `port` and `state` MAY not be returned by the request due to internal limitations. The `port`/`state` SHOULD be determined using a standard `GET Show` request.

```
POST /sessions
Authorization: Basic <base64 encoded username:password>
Accepts: application/json
Content-Type: application/json

{
  "desktop": <desktop>
}

HTTP/2 201 Created
Content-Type: application/json
{ <session-resource-object> }
```

#### Other Responses

Not all of the `desktop` types are available which is most likely due to missing dependencies. The application will do its best to "prepare" a desktop without installing any additional dependencies. The following error will be raised if the `destkop` is still not available:

```
HTTP/2 400 Bad Request
Content-Type: application/json

{
  "errors": [
    {
      "status": "400",
      "code": "Desktop Not Prepared"
    }
  ]
}
```

The following error SHALL be returned if the `desktop` is missing.

```
HTTP/2 404 Not Found
Content-Type: application/json

{
  "errors": [
    {
      "status": "404",
      "code": "Not Found",
      "detail": "Could not find 'desktop': <missing-id>"
    }
  ]
}
```

### DELETE Terminate

Terminate an active session. It SHALL respond `204 No Content` iff the session was successfully terminated.

```
DELETE /sessions/:id`
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

HTTP/2 204 No Content
```

### GET Screenshot

Retrieve the screenshot associated with a session as `image/png`. This route can be directly embedded into a `src` tag.

```
GET /sessions/:id/screenshot.png
Authorization: Basic <base64 encoded username:password>
Accepts: image/png

HTTP/2 200 OK
Content-Type: image/png
... Image ...
```

## Desktops

### ID

The `id` MUST be alphanumeric

### GET Index

Returns a list of the currently available desktops. The list MAY contain desktops which could not be verified when the application loaded/refreshed.

```
GET /desktops
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

HTTP/2 200 OK
{
  "data": [
    <desktop-resource-object>,
    ...
  ]
}
```

### GET Show

Returns metadata about a particular `desktop`.

```
GET /desktop/:id
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

HTTP/2 200 OK
{
  "id": "<UUID>",
  "verified": <true|false>,
  "summary": "<summary>",
  "homepage": "<home-url>"
}
```

#### Response Attributes

*id*

The name of the desktop

Type: String

*verified:*

Whether the desktop has been checked for the required dependencies. Sessions creation MAY fail for unverified desktops.

Type: Boolean

*summary:*

A short description on the desktop

Type: String

*homepage:*

The URL to the desktops homepage when available, otherwise None

Type: None | String - URL

#### Other Responses

```
HTTP/2 404 Not Found
Content-Type: application/json

{
  "errors": [
    {
      "status": "404",
      "code": "Not Found",
      "detail": "Could not find 'desktop': <missing-id>"
    }
  ]
}
```


# Copyright and License

Eclipse Public License 2.0, see LICENSE.txt for details.

Copyright (C) 2020-present Alces Flight Ltd.

This program and the accompanying materials are made available under the terms of the Eclipse Public License 2.0 which is available at https://www.eclipse.org/legal/epl-2.0, or alternative license terms made available by Alces Flight Ltd - please direct inquiries about licensing to licensing@alces-flight.com.

FlightDesktopServer is distributed in the hope that it will be useful, but WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more details.

