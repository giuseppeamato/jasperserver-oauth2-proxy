import ballerina/http;
import ballerina/config;
import pz8/oauth2_xacml;

int proxyPort = config:getAsInt("jasperserver.proxy.port");
string contextPath = config:getAsString("jasperserver.proxy.contextPath");
string serviceEndpoint = config:getAsString("jasperserver.proxy.serviceEndpoint");
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

oauth2_xacml:GatewayConfiguration gatewayConf = {
    idsEndpoint: idsEndpoint,
    idsUsername: idsUsername,
    idsPassword: idsPassword,
    truststorePath: truststorePath,
    truststorePassword: truststorePassword,    
    idsIntrospectPath: introspectPath,
    idsUserInfoPath: userInfoPath,
    idsAuthorizationPath: authorizationPath
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
http:Client testClient = new(serviceEndpoint);

@http:ServiceConfig {
    basePath: contextPath
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
        var response = oauth2Client->gateway(caller, request, testClient, <@untainted> serviceUrl, authorizationEnabled, setAuthInfo);
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
