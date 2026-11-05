// J Harness Windows Service LAB candidate, .NET Framework 4.x.
// Not installed. Supports ONLY read-only status on a public named pipe.
// No CLI launch, credential use, filesystem mutation, protected UI, or enforcement.
using System;
using System.IO;
using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text;
using System.Threading;

public sealed class JHarnessPhase1LabService : ServiceBase {
  private Thread listener;
  private volatile bool stopping;
  private NamedPipeServerStream current;
  public JHarnessPhase1LabService() { ServiceName="JHarnessPhase1Lab"; CanStop=true; AutoLog=false; }
  public static void Main(string[] args) {
    // Requires separate OS service principal; console mode is not an authenticated service.
    if(args.Length==1 && args[0]=="--console-lab") {
      using(var instance=new JHarnessPhase1LabService()) {
        instance.OnStart(new string[0]);
        Console.WriteLine("READ_ONLY_LAB_PIPE_READY_NOT_OS_ENFORCED");
        Console.ReadLine();
        instance.OnStop();
      }
    } else ServiceBase.Run(new JHarnessPhase1LabService());
  }
  protected override void OnStart(string[] args) {
    stopping=false;
    listener=new Thread(Serve) { IsBackground=true, Name="JHarnessPhase1ReadOnlyPipe" };
    listener.Start();
  }
  protected override void OnStop() {
    stopping=true;
    try {if(current!=null)current.Dispose();} catch(ObjectDisposedException) {}
    if(listener!=null)listener.Join(2500);
  }
  private static PipeSecurity ReadOnlyProtocolPipeAcl() {
    var acl=new PipeSecurity();
    // Public pipe has no mutating methods. ACL protects transport access, not user presence.
    acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),PipeAccessRights.FullControl,AccessControlType.Allow));
    acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid,null),PipeAccessRights.FullControl,AccessControlType.Allow));
    acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid,null),PipeAccessRights.ReadWrite,AccessControlType.Allow));
    return acl;
  }
  private void Serve() {
    while(!stopping) {
      try {
        using(var pipe=new NamedPipeServerStream("JHarness.Phase1.Status",PipeDirection.InOut,1,
                 PipeTransmissionMode.Byte,PipeOptions.None,1024,1024,ReadOnlyProtocolPipeAcl())) {
          current=pipe;
          pipe.WaitForConnection();
          if(stopping) return;
          pipe.ReadTimeout=2000; pipe.WriteTimeout=2000;
          var line=new StringBuilder(); int next;
          while(line.Length<64 && (next=pipe.ReadByte())>=0 && next!='\n') line.Append((char)next);
          string request=line.ToString().Trim();
          // Fail closed: even local administrator clients cannot toggle from this pipe.
          string reply=(request=="status"||request=="doctor")
            ? "{\"product\":\"J Harness\",\"state\":\"BLOCKED\",\"reason\":\"WINDOWS_LAB_SERVICE_NO_TRUSTED_EXECUTOR\",\"enforcement\":\"NOT_ATTESTED\",\"launchAuthorized\":false,\"toggleAvailable\":false}"
            : "{\"decision\":\"DENY\",\"reason\":\"READ_ONLY_PIPE\"}";
          byte[] bytes=Encoding.UTF8.GetBytes(reply+"\n");pipe.Write(bytes,0,bytes.Length);pipe.Flush();
        }
      } catch(IOException) {if(stopping)return;} catch(ObjectDisposedException) {if(stopping)return;}
      catch(Exception) { if(stopping)return; Thread.Sleep(200); }
      finally {current=null;}
    }
  }
}
