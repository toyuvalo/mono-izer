// MonoIzerLauncher.cs -- MonoIzer.exe, the right-click entry point (v1.1.0)
// Usage: MonoIzer.exe "<file>"          -> mono (left channel)
//        MonoIzer.exe --split "<file>"  -> split L / R (one prefix dialog per batch)
// A compiled launcher instead of a VBScript that starts hidden PowerShell:
// antivirus flags that chain. Same logic as Shrink Menu's launcher:
//   1. Explorer starts one instance per selected file; a lock file lets only the
//      first one do the work.
//   2. Find the Explorer window whose selection holds the right-clicked path (%1)
//      and collect ALL its selected files (multi-select).
//   3. Write the list as UTF-8 and start mono-izer.ps1 with no console window.
//      The script converts the files one at a time.
// Build: build.cmd.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("mono-izer")]
[assembly: AssemblyDescription("mono-izer right-click stereo to mono converter")]
[assembly: AssemblyProduct("mono-izer")]
[assembly: AssemblyCompany("DVLCE")]
[assembly: AssemblyCopyright("MIT with Commons Clause")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

static class MonoIzerLauncher
{
    [STAThread]
    static int Main(string[] args)
    {
        bool split = args.Length > 0 && args[0] == "--split";
        string rightClicked = args.Length > (split ? 1 : 0) ? args[split ? 1 : 0] : "";
        string tempDir = Path.GetTempPath();
        // One lock per mode, so a mono batch and a split batch do not swallow each other.
        string lockFile = Path.Combine(tempDir, split ? "mono_izer_split.lock" : "mono_izer.lock");

        try
        {
            if (File.Exists(lockFile) &&
                (DateTime.Now - File.GetLastWriteTime(lockFile)).TotalSeconds < 5)
                return 0;
            File.WriteAllText(lockFile, "");
        }
        catch { return 0; }

        // Let Explorer finish launching all instances.
        Thread.Sleep(400);

        var files = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        try { CollectFromExplorer(rightClicked, files, seen); } catch { }

        // Fallback: the right-clicked file alone if no window matched.
        if (files.Count == 0 && rightClicked != "" && File.Exists(rightClicked))
            files.Add(rightClicked);

        try { File.Delete(lockFile); } catch { }

        if (files.Count == 0) return 0;

        // A unique list file per batch, so a second right-click cannot overwrite
        // a list the script has not read yet.
        string listFile = Path.Combine(tempDir, "mono_izer_" + Guid.NewGuid().ToString("N") + ".txt");
        File.WriteAllLines(listFile, files.ToArray(), new UTF8Encoding(true));

        StartScript("-ListFile \"" + listFile + "\"" + (split ? " -Mode Split" : ""));
        return 0;
    }

    static void StartScript(string scriptArgs)
    {
        string script = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "mono-izer.ps1");
        // -ExecutionPolicy Bypass stays: the Windows client default policy
        // (Restricted) refuses every script, signed or not.
        var psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" " + scriptArgs);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        Process.Start(psi);
    }

    static void CollectFromExplorer(string rightClicked, List<string> files, HashSet<string> seen)
    {
        Type shellType = Type.GetTypeFromProgID("Shell.Application");
        dynamic shell = Activator.CreateInstance(shellType);
        foreach (dynamic wnd in shell.Windows())
        {
            dynamic selected;
            try
            {
                if (wnd == null) continue;
                dynamic doc = wnd.Document;
                if (doc == null) continue;
                selected = doc.SelectedItems();
            }
            catch { continue; }   // not a folder view
            if (selected == null || selected.Count == 0) continue;

            bool match = false;
            foreach (dynamic item in selected)
            {
                if (string.Equals((string)item.Path, rightClicked, StringComparison.OrdinalIgnoreCase))
                { match = true; break; }
            }
            if (!match) continue;

            foreach (dynamic item in selected)
            {
                string p = item.Path;
                string ext = Path.GetExtension(p).ToLowerInvariant();
                if ((ext == ".wav" || ext == ".mp3") && seen.Add(p)) files.Add(p);
            }
            return;
        }
    }
}
