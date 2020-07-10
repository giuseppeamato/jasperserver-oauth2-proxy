Jasper Server Oauth2 Auth Proxy

# Module Overview

This module allows you to add in a very simple way an OAuth2 security layer in front of Jasper Server REST services to use them in a single sign on context. Moreover, since this module is based on the `pz8/oauth2_xacml` connector, it is also possible to query authorization policies on the IDS / PDP. See [oauth2_xacml](https://github.com/giuseppeamato/oauth2-xacml-proxy) project page for details.

The main goal of this project is to allow to invoke Jasper Server REST services from untrusted clients (like Javascript client-side web applications) in a quite safe mode. 
This component does not perform token generation, but simply checks the validity of opaque tokens passed to it, clients have to independently obtains an oauth2 token following a selected grant type. 

The key idea is to configure Jasper Server with token based authentication and protect it behind this proxy, where the oauth2 access token is used to check authentication/authorizations and to obtain all the info in order to generate the Jasper Server preauth token.

## Usage

You can pull the module from Ballerina Central using the command:
```ballerina
$ ballerina pull pz8/jasperserver_oauth2_proxy
```

Then you have to properly configure the `config.toml` file and launch the build command, after that you can start the module:

```ballerina
$ ballerina run .\target\bin\jasperserver_oauth2_proxy.jar --b7a.config.file=.\config.toml 
```

# Configuration

## Ballerina proxy
On the ballerina module side there are few parameters to set, in the `[jasperserver.proxy]` block of the `config.toml` file:
+ `port`: the port of the proxy service
+ `contextPath`: the context path of the proxy service 
+ `serviceEndpoint`: the Jasper Server REST service base endpoint
+ `allowOrigins`: tells the browser to allow requesting resources from the specified origin, the literal value "`*`" can be specified, as a wildcard.
+ `keystorePath`: the path of keystore file, needed for HTTPS connections
+ `keystorePassword`: the password of keystore file
+ `authorizationEnabled`: if `true` the proxy makes an xacml query to the policy decision point, passing as parameters the current logged username, the path of the remote resource and the http request method used
+ `principalParameter`: the name of the header attribute containing the preauth token
+ `subjectClaim`: the name of the user profile attribute containing the username of the logged user
+ `rolesClaim`: the name of the user profile attribute containing the roles of the logged user

and in `[oauth2_xacml]` block:

+ `endpoint`: the base URL of the Authorization Server
+ `username`: username of user on the authorization server allowed to invoke introspection endpoint
+ `password`: password of user on the authorization server allowed to invoke introspection endpoint
+ `introspectPath`: relative path to invoke the OAuth introspection endpoint and validate the token
+ `userInfoPath`: relative path to invoke the User Profile Information service
+ `authorizationPath`: relative path to invoke the Policy Decision Point entitlement service
+ `truststorePath`: path to the .p12 truststore file for SSL connections to the authorization server
+ `truststorePassword`: password for truststore file
+ `timeoutInMillis`: timeout of http connection to the authorization server
+ **`authenticationCache`** / **`authorizationCache`** (**OPTIONAL**)
    + `size`: maximum number of entries allowed for the cache
    + `evictionFactor`: The factor by which the entries will be evicted once the cache is full. The eviction policy is based on LRU algorithm.
    At the time of eviction (**size** * **evictionFactor**) entries get removed from the cache.
    + `maxAgeInSeconds`: expiration of entries in seconds 
    + `cleanupIntervalInSeconds`: The interval time of the task which cleans expired cache entries
+ **`circuitBreaker`** (**OPTIONAL**)
   + `timeWindowInMillis`: Time period in milliseconds for which the failure threshold is calculated.
   + `bucketSizeInMillis`: The granularity (in milliseconds) at which the time window slides.
   + `requestVolumeThreshold`: Minimum number of requests that will trip the circuit
   + `failureThreshold`: The threshold for request failures. When this threshold exceeds, the circuit trips. 
   + `resetTimeInMillis`: The time period (in milliseconds) to wait before attempting to make another request to the upstream service.
   + `statusCodes`: HTTP response status codes that are considered as failures

In the provided example configuration file are shown the identity server credentials `admin`/`admin`, those strings are encrypted with the `encrypt` ballerina command using the secret word "`ballerina`", so at the startup the module will prompt you to insert that value; in alternative you can provide a `secret.txt` file containing the secret and referencing it in the command:

```ballerina
$ ballerina run .\target\bin\jasperserver_oauth2_proxy.jar --b7a.config.file=.\config.toml --b7a.config.secret=.\secret.txt 
```

## Jasper Server 

In order to configure Jasper Server with Token based authentication, you have remove `sample-*` prefix from the `applicationContext-externalAuth-preAuth.xml` configuration file name (provided in the installation dir) and place it to the WEB-INF folder of the application server.

Then edit the file to disable the presence of token in the request parameters, since we only want it in request header:

```xml
<property name="tokenInRequestParam" value="false"/>
```

>When Jasper Server token-based authentication is used, it is extremely important that your external system is configured properly to prevent an attacker from forging the token.

## Identity Server

Obviously, on the Identity Server needs to exist a configuration of a service provider.

To keep the Identity Server user store (that would be LDAP or database) and the Jasper Server synchronized, there is a wide variety of approaches, I often used [LSC project](https://github.com/lsc-project/lsc).


## Compatibility
|                          |    Version     |
|:------------------------:|:--------------:|
| Ballerina Language       | 1.2.4          |
| Jasper Server            | 7.2            |






