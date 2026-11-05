// J Harness v8 Phase 2 - disposable Windows SCM/LocalService security laboratory.
// Not a production service. Read-only IPC only; NEVER authorizes any CLI/tool launch.
using System;
using System.IO;
using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

public sealed class JHarnessPhase2LabService : ServiceBase
{
    private readonly string labRoot, pipeName;
    private readonly Thread worker;
    private NamedPipeServerStream active;
    private volatile bool stopping;

    public sealed class State
    {
        public int schema { get; set; }
        public string desired { get; set; }
        public int epoch { get; set; }
        public string policySha256 { get; set; }
    }

    private JHarnessPhase2LabService(string root, string name, string pipe)
    {
        labRoot = root;
        pipeName = pipe;
        ServiceName = name;
        CanStop = true;
        AutoLog = false;
        worker = new Thread(Serve) { IsBackground = true, Name = "JHarnessPhase2StatusOnly" };
    }

    public static void Main(string[] args)
    {
        if (args.Length != 4 || args[0] != "--service")
            throw new InvalidOperationException("SCM_SERVICE_LAB_ARGUMENTS_REQUIRED");
        string root = Path.GetFullPath(args[1]);
        string parent = Path.GetDirectoryName(root);
        string expectedGrandparent = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData).TrimEnd('\\');
        if (!String.Equals(Path.GetDirectoryName(parent), expectedGrandparent, StringComparison.OrdinalIgnoreCase) ||
            !Path.GetFileName(parent).StartsWith("JHarnessPhase2LabParent_", StringComparison.OrdinalIgnoreCase) ||
            !Path.GetFileName(root).StartsWith("jh-phase2-lab-", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("DISPOSABLE_PROGRAMDATA_LAB_ROOT_ONLY");
        if ((File.GetAttributes(parent) & FileAttributes.ReparsePoint) != 0 ||
            (File.GetAttributes(root) & FileAttributes.ReparsePoint) != 0 ||
            File.ReadAllText(Path.Combine(parent, ".lab-parent-marker")).Trim() != "J_HARNESS_PHASE2_DISPOSABLE_PARENT")
            throw new InvalidOperationException("UNTRUSTED_PARENT_DIRECTORY");
        if (!System.Text.RegularExpressions.Regex.IsMatch(args[2], @"^JHP2Lab_[0-9a-f]{12}$") ||
            !System.Text.RegularExpressions.Regex.IsMatch(args[3], @"^JHP2Status_[0-9a-f]{12}$"))
            throw new InvalidOperationException("INVALID_SERVICE_OR_PIPE_NAME");
        if (File.ReadAllText(Path.Combine(root, ".lab-marker")).Trim() != "J_HARNESS_PHASE2_DISPOSABLE_WINDOWS_LAB")
            throw new InvalidOperationException("LAB_MARKER_INVALID");
        using (var service = new JHarnessPhase2LabService(root, args[2], args[3]))
            ServiceBase.Run(service);
    }

    protected override void OnStart(string[] args)
    {
        string sid = WindowsIdentity.GetCurrent().User.Value;
        if (sid != "S-1-5-19") throw new InvalidOperationException("LOCALSERVICE_IDENTITY_REQUIRED");
        stopping = false;
        worker.Start();
    }

    protected override void OnStop()
    {
        stopping = true;
        try { if (active != null) active.Dispose(); } catch (ObjectDisposedException) { }
        worker.Join(3000);
    }

    private static PipeSecurity StatusPipeAcl()
    {
        var acl = new PipeSecurity();
        acl.SetAccessRuleProtection(true, false);
        acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.LocalServiceSid, null), PipeAccessRights.FullControl, AccessControlType.Allow));
        acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null), PipeAccessRights.FullControl, AccessControlType.Allow));
        acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null), PipeAccessRights.FullControl, AccessControlType.Allow));
        // Transport is readable/writable to authenticated users. Protocol grants NO write operations.
        acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null), PipeAccessRights.ReadWrite, AccessControlType.Allow));
        return acl;
    }

    private static bool IsRegularAndNotReparse(string file)
    {
        var attr = File.GetAttributes(file);
        return (attr & FileAttributes.ReparsePoint) == 0 && (attr & FileAttributes.Directory) == 0;
    }

    private object Observe()
    {
        string desired = "UNKNOWN";
        string reason = "WINDOWS_ACL_ONLY_NO_TRUSTED_CLI_GATE";
        try
        {
            string protectedRoot = Path.Combine(labRoot, "protected");
            if ((File.GetAttributes(protectedRoot) & FileAttributes.ReparsePoint) != 0)
                throw new InvalidDataException("PROTECTED_REPARSE_REFUSED");
            string policyPath = Path.Combine(protectedRoot, "policy.json");
            string statePath = Path.Combine(protectedRoot, "state.json");
            if (!IsRegularAndNotReparse(policyPath) || !IsRegularAndNotReparse(statePath))
                throw new InvalidDataException("PROTECTED_FILE_TYPE_REFUSED");
            byte[] policy = File.ReadAllBytes(policyPath);
            State state = new JavaScriptSerializer().Deserialize<State>(File.ReadAllText(statePath, Encoding.UTF8));
            if (state == null || state.schema != 1 || state.epoch < 1 ||
                !System.Text.RegularExpressions.Regex.IsMatch(state.policySha256 ?? "", "^[a-f0-9]{64}$"))
                throw new InvalidDataException("STATE_FORMAT_INVALID");
            using (var sha = SHA256.Create())
            {
                string observed = BitConverter.ToString(sha.ComputeHash(policy)).Replace("-", "").ToLowerInvariant();
                if (observed != state.policySha256) throw new InvalidDataException("POLICY_SHA256_MISMATCH");
            }
            if (state.desired != "ON") throw new InvalidDataException("UNAUTHORIZED_STATE_IN_TEST_LAB");
            desired = "ON";
        }
        catch (Exception e)
        {
            reason = "TRUST_STORE_FAILURE_" + e.GetType().Name;
        }
        return new {
            product = "J Harness",
            phase = "PHASE2_DISPOSABLE_WINDOWS_LAB",
            state = "BLOCKED",
            desired = desired,
            reason = reason,
            enforcement = "NOT_ATTESTED",
            launchAuthorized = false,
            toggleAvailable = false,
            serviceSid = WindowsIdentity.GetCurrent().User.Value
        };
    }

    private void Serve()
    {
        var json = new JavaScriptSerializer();
        while (!stopping)
        {
            try
            {
                using (var pipe = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1,
                    PipeTransmissionMode.Byte, PipeOptions.None, 4096, 4096, StatusPipeAcl()))
                {
                    active = pipe;
                    pipe.WaitForConnection();
                    if (stopping) return;
                    pipe.ReadTimeout = 3000;
                    pipe.WriteTimeout = 3000;
                    var request = new StringBuilder();
                    int c;
                    while (request.Length < 80 && (c = pipe.ReadByte()) >= 0 && c != '\n')
                        if (c >= 32 && c <= 126) request.Append((char)c);
                    string op = request.ToString();
                    object reply = (op == "status" || op == "doctor") ? Observe()
                        : (object)new { decision = "DENY", reason = "READ_ONLY_PIPE_NO_MUTATION" };
                    byte[] response = Encoding.UTF8.GetBytes(json.Serialize(reply) + "\n");
                    pipe.Write(response, 0, response.Length);
                    pipe.Flush();
                }
            }
            catch (IOException) { if (stopping) return; }
            catch (ObjectDisposedException) { if (stopping) return; }
            catch (Exception) { if (stopping) return; Thread.Sleep(150); }
            finally { active = null; }
        }
    }
}
