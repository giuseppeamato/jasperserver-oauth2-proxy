import ballerina/http;
import ballerina/config;
import pz8/oauth2_xacml;

int proxyPort = config:getAsInt("jasperserver.proxy.port");
string contextPath = config:getAsString("jasperserver.proxy.contextPath");
string serviceEndpoint = config:getAsString("jasperserver.proxy.serviceEndpoint");
string allowOrigins = config:getAsString("jasperserver.proxy.allowOrigins");
string keystorePath = config:getAsString("jasperserver.proxy.keystorePath");
string keystorePassword = config:getAsString("jasperserver.proxy.keystorePassword");
boolean authorizationEnabled = config:getAsBoolean("jasperserver.proxy.authorizationEnabled");
string principalParameter = config:getAsString("jasperserver.proxy.principalParameter");
string subjectClaim = config:getAsString("jasperserver.proxy.subjectClaim");
string rolesClaim = config:getAsString("jasperserver.proxy.rolesClaim");

string idsEndpoint = config:getAsString("oauth2_xacml.endpoint"); 
string idsUsername = config:getAsString("oauth2_xacml.username"); 
string idsPassword = config:getAsString("oauth2_xacml.password");
string truststorePath = config:getAsString("oauth2_xacml.truststorePath");
string truststorePassword = config:getAsString("oauth2_xacml.truststorePassword");
string introspectPath = config:getAsString("oauth2_xacml.introspectPath");
string userInfoPath = config:getAsString("oauth2_xacml.userInfoPath");
string authorizationPath = config:getAsString("oauth2_xacml.authorizationPath");
int timeoutInMillis = config:getAsInt("oauth2_xacml.timeoutInMillis", 20000);

int authSize = config:getAsInt("oauth2_xacml.authenticationCache.size");
float authEvictionFactor = config:getAsFloat("oauth2_xacml.authenticationCache.evictionFactor");
int authMaxAgeInSeconds = config:getAsInt("oauth2_xacml.authenticationCache.maxAgeInSeconds");
int authCleanupIntervalInSeconds = config:getAsInt("oauth2_xacml.authenticationCache.cleanupIntervalInSeconds");
int authzSize = config:getAsInt("oauth2_xacml.authorizationCache.size");
float authzEvictionFactor = config:getAsFloat("oauth2_xacml.authorizationCache.evictionFactor");
int authzMaxAgeInSeconds = config:getAsInt("oauth2_xacml.authorizationCache.maxAgeInSeconds");
int authzCleanupIntervalInSeconds = config:getAsInt("oauth2_xacml.authorizationCache.cleanupIntervalInSeconds");

int timeWindowInMillis = config:getAsInt("oauth2_xacml.circuitBreaker.timeWindowInMillis");
int bucketSizeInMillis = config:getAsInt("oauth2_xacml.circuitBreaker.bucketSizeInMillis");
int requestVolumeThreshold = config:getAsInt("oauth2_xacml.circuitBreaker.requestVolumeThreshold");
float failureThreshold = config:getAsFloat("oauth2_xacml.circuitBreaker.failureThreshold");
int resetTimeInMillis = config:getAsInt("oauth2_xacml.circuitBreaker.resetTimeInMillis");
int[]|error statusCodes = int[].constructFrom(config:getAsArray("oauth2_xacml.circuitBreaker.statusCodes"));

oauth2_xacml:GatewayConfiguration gatewayConf = {
    idsEndpoint: idsEndpoint,
    idsUsername: idsUsername,
    idsPassword: idsPassword,
    truststorePath: truststorePath,
    truststorePassword: truststorePassword,    
    idsIntrospectPath: introspectPath,
    idsUserInfoPath: userInfoPath,
    idsAuthorizationPath: authorizationPath,
    authenticationCache: {
        size: authSize,
        evictionFactor:authEvictionFactor,
        maxAgeInSeconds:authMaxAgeInSeconds,
        cleanupIntervalInSeconds:authCleanupIntervalInSeconds
    },
    authorizationCache: {
        size: authzSize,
        evictionFactor:authzEvictionFactor,
        maxAgeInSeconds:authzMaxAgeInSeconds,
        cleanupIntervalInSeconds:authzCleanupIntervalInSeconds
    },
    circuitBreaker: {
        timeWindowInMillis: timeWindowInMillis,
        bucketSizeInMillis: bucketSizeInMillis,
        requestVolumeThreshold: requestVolumeThreshold,
        failureThreshold: failureThreshold,
        resetTimeInMillis: resetTimeInMillis,
        statusCodes: check statusCodes
    },
    timeoutInMillis: timeoutInMillis
};
oauth2_xacml:Client oauth2Client = new(gatewayConf);

listener http:Listener httpJasperServerListener = new(proxyPort, {
    secureSocket: {
        keyStore: {
            path: keystorePath,
            password: keystorePassword
        }
    }
});
http:Client targetClient = new(serviceEndpoint);

@http:ServiceConfig {
    basePath: contextPath,
    cors: {
         allowOrigins: [allowOrigins],
         allowCredentials: false,
         allowHeaders: ["authorization","Access-Control-Allow-Origin","Content-Type","SOAPAction"]
    }
}
service jasperServerSecureProxy on httpJasperServerListener {

    @http:ResourceConfig {
        methods: ["GET", "POST", "PUT", "DELETE"],
        path: "/*"
    }
    resource function proxy(http:Caller caller, http:Request request) returns error? {
        request.removeHeader(principalParameter);
        string serviceUrl = request.rawPath.substring(contextPath.length());
        serviceUrl = copyParameters(serviceUrl, <@untainted> request);
        var response = oauth2Client->gateway(caller, <@untainted> request, targetClient, <@untainted> serviceUrl, authorizationEnabled, setAuthInfo);
    }
}

function copyParameters(string serviceUrl, http:Request request) returns @untainted string {
    string destinationUrl = serviceUrl;
    destinationUrl = destinationUrl.concat("?&");
    foreach var item in request.getQueryParams().keys() {
        string[] values = <string[]> request.getQueryParamValues(item);
        foreach var value in values {
            destinationUrl = destinationUrl.concat(item, "=", value);
        }
    }
    return destinationUrl;
}

function setAuthInfo(http:Request request, json userInfo) returns http:Request {
    map<anydata>|error userInfoMap = map<anydata>.constructFrom(userInfo);
    if (userInfoMap is map<anydata>) {
        request.setHeader(principalParameter, string `u=${userInfoMap[subjectClaim].toString()}|r=${userInfoMap[rolesClaim].toString()}`);
    }
    return request;
}
