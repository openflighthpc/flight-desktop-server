# Desktop Management API server (DMA)

A Desktop Management API server shall be developed.  It needs to be able to 

 1. Authenticate users using the same mechanism as used for user
    authentication on the cluster itself.  Notably PAM.

 2. Run the `flight desktop` command in a clean environment for the correct
    user and return a representation of the results.

It is envisioned that the server would be implemented in Ruby and make use of
`rpam` for authentication.

The canonical source of what desktops are available to be launched and
what desktops are currently running, shall be the output of the various
`flight desktop` commands.  As there is no requirement for historical desktop
usage to be provided, it is not envisioned that the DMA would require a model
layer in the first draft of its implementation.

An proof of concept Desktop Management API can be found in the
[https://github.com/alces-flight/flight-desktop-server](https://github.com/alces-flight/flight-desktop-server)
repository.

The API it provides is lacking in a number of aspects, however the `Session`
class it provides looks to be a good starting point on which to build a
mechanism for running `flight desktop` in a clean environment.

Its authentication mechanism may also be suitable, but requires further
investigation to determine that.


## Limitations in functionality

The initial implementation will not provide functionality to

 1. Prepare available session types.  It is expected that out-of-band
    communication will take place between cluster users and cluster
    administrators to prepare any requested session types.

 2. List available session types.  Whilst ideally this would be included, for
    the initial implementation, we can hardcode the session types in the
    client.  This limitation may be revisited in a later future version.

## API

The API provided by DMA is detailed below.

### Headers

All requests (unless otherwise noted) should set the following headers

```
Authorization: Basic <base64 encoded username:password>
Accepts: application/json
```

The `Authorization` header is a base64 encoded `<username>:<password>` tuple.
Where the username and password are the user's username and password for the
cluster.


### Get currently running sessions

Return a list of all currently running desktop sessions for the identified
user.

```
GET /sessions
Authorization: Basic <base64 encoded username:password>
Accepts: application/json
```

#### Handling the request

The list of sessions are to be determined by running `flight desktop list` in
a clean environment as the user identified in the `Authorization` header.

#### Response elements

The representation for each session must include at a minimum its `id`
and `type`.
*id*

The identifier for the session as determined by `flight desktop`.

Type: String

*type*

The session type for the session as determined by `flight desktop`.

Type: String

*image*

A Base64 enconding of the latest screenshot for the session or null.  The
image if present, should be a PNG.

Type: String (Base64 encoding of a PNG image).

#### Example

```
HTTP/2 200 OK
Content-Type: application/json

{
  "id": "1740a970-73e2-42bb-b740-baadb333175d",
  "type": "terminal",
  "image": <base64 enconding of a PNG file>,
}
```

### Start a new desktop

Start a new desktop of the given type for the identified user.

```
POST /sessions
Authorization: Basic <base64 encoded username:password>
Accepts: application/json

{
  "type": <type>
}
```

#### Handling the request

The desktop is to be started by by running `flight desktop start <type>` in a
clean environment as the user identified in the `Authorization` header.

`flight desktop` could fail to create a session if the session type has not
been verified.  DMA should detect that error and verify the session.  If the
session is verified, DMA should then create the session.  If the session
cannot be verified an error should be reported from DMA as follows:

```
HTTP/2 400 Bad Request
Content-Type: application/json

{
  "errors": [{
    "status": "400",
    "code": "Session Type Not Prepared"
  }]
}
```

If `flight desktop` reports that an unknown desktop type was provided, DMA
should respond as follows:

```
HTTP/2 400 Bad Request
Content-Type: application/json

{
  "errors": [{
    "status": "400",
    "code": "Unknown Desktop"
  }]
}
```



#### Request elements

*type*

A session type supported by `flight desktop`.  Currently, one of `chrome`,
`gnome`, `kde`, `terminal`, `xfce` and `xterm`.


#### Response elements

The values of all response elements are obtained from the output of the above
`flight desktop` command.


*id*

The "Identity" for the session.

Type: String

*type*

The "Type" for the session.

Type: String

*ip*

The "Host IP" for the session.

Type: String


*hostname*

The "Hostname" for the session.

Type: String

*port*

The "Port" for the session.

Type: String

*password*

The "Password" for the session.

Type: String


```
HTTP/2 200 OK
Content-Type: application/json

{
  "id": "1740a970-73e2-42bb-b740-baadb333175d",
  "type": "terminal",
  "ip": "172.17.0.3",
  "hostname": "b32d194c5ebb",
  "port": "5901",
  "password": "DA6khY3r",
}
```


### Get access details for a session

Return the details for the given session.

```
GET /sessions/:id
Authorization: Basic <base64 encoded username:password>
Accepts: application/json
```

#### Handling the request

The desktop details are to be determined by running `flight desktop show <id>`
in a clean environment as the user identified in the `Authorization` header.

#### Request elements

*id*

The identifier of the session.

Type: String


#### Response elements

As detailed above for `POST /sessions`.

#### Example

```
HTTP/2 200 OK
Content-Type: application/json

{
  "id": "1740a970-73e2-42bb-b740-baadb333175d",
  "type": "terminal",
  "ip": "172.17.0.3",
  "hostname": "b32d194c5ebb",
  "port": "5901",
  "password": "DA6khY3r",
}
```


### Get the latest screenshot for a session

Return the latest screenshot for the given session.

```
GET /sessions/:id/screenshot`
Authorization: Basic <base64 encoded username:password>
Accepts: image/png
```

#### Handling the request

When `flight desktop` starts a new session a process is created to save
screenshots of the session.  By default,
the file used for storing the screenshots is
`"${XDG_CACHE_HOME:-$HOME/.cache}/flight/desktop/sessions/<id>/session.png"`.

If this file is present, DMA should return the contents of the file.
Otherwise it should respond with a `404`.

In the initial implementation, support for screenshots saved in a non-default
location is not provided.


#### Response element

A PNG of the latest screenshot for the identified session.


#### Errors

If a screenshot has not yet been saved for the session, respond with a `404`.



### Terminate a session

Terminate the identified running session.

```
DELETE /sessions/:id`
Authorization: Basic <base64 encoded username:password>
Accepts: application/json
```

#### Handling the request

The session is to be terminated by running `flight desktop kill <id>` in a
clean environment as the user identified in the `Authorization` header.
`<id>` is the identifier of the session to be terminated.

Terminating the session synchronously is acceptable.

#### Response

If the session is found and terminated, return `204 No Content`.

If the session cannot be found return `404 Not Found`.

If the session cannot be terminated for some reason return a `500 Internal
Server Error`.


#### Example


```
HTTP/2 500 Internal Server Error
Content-Type: application/json

{
  "errors": [{
    "status": "500",
    "code": "Internal Server Error"
  }]
}
```




#### Common errors

All errors reported should follow the [JSON:API error
specification](https://jsonapi.org/format/#errors).  In particular, the `code`
key should be included for all errors.  The particular code to use is detailed
in this document.

All POST/PATCH/PUT/DELETE requests must formatted as JSON. This includes
setting the `Content-Type` header to `application/json`. Failure to do so will
raise the following error.

Example

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

If the given user cannot be found in `/etc/passwd`, a "User Not Found" error
should be reported.

Example

```
HTTP/2 404 Not Found
Content-Type: application/json

{
  "errors": [{
    "status": "404",
    "code": "User Not Found"
  }]
}
```

If the given user is `root` or if creating a process as the given user fails,
a "User Not Available" error should be reported.

Example

```
HTTP/2 422 Unprocessable Entity
Content-Type: application/json

{
  "errors": [{
    "status": "422",
    "code": "User Not Available"
  }]
}
```

XXX We should consider if distinguishing "User Not Found" from "User Not
Available" exposes the configured users of the cluster and if this is
something we wish to avoid.

If communication with `flight desktop` fails in an unexpected way return a 500
error.

```
HTTP/2 500 Internal Server Error
Content-Type: application/json

{
  "errors": [{
    "status": "500",
    "code": "Internal Server Error"
  }]
}
```
