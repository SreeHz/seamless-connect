package com.seamlessconnect;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

public class RootHelper {

    public static boolean isRootAvailable() {
        CommandResult res = runSu("id");
        return res.exitCode == 0 && res.stdout.contains("uid=0");
    }

    public static CommandResult runSu(String command) {
        StringBuilder stdout = new StringBuilder();
        StringBuilder stderr = new StringBuilder();
        int exitCode = -1;

        try {
            Process process = Runtime.getRuntime().exec("su");
            DataOutputStream os = new DataOutputStream(process.getOutputStream());
            BufferedReader is = new BufferedReader(new InputStreamReader(process.getInputStream()));
            BufferedReader es = new BufferedReader(new InputStreamReader(process.getErrorStream()));

            os.writeBytes(command + "\n");
            os.writeBytes("exit\n");
            os.flush();

            String line;
            while ((line = is.readLine()) != null) {
                stdout.append(line).append("\n");
            }
            while ((line = es.readLine()) != null) {
                stderr.append(line).append("\n");
            }

            exitCode = process.waitFor();
            os.close();
            is.close();
            es.close();
        } catch (Exception e) {
            stderr.append(e.getMessage());
        }

        return new CommandResult(exitCode, stdout.toString().trim(), stderr.toString().trim());
    }

    public static class CommandResult {
        public final int exitCode;
        public final String stdout;
        public final String stderr;

        public CommandResult(int exitCode, String stdout, String stderr) {
            this.exitCode = exitCode;
            this.stdout = stdout;
            this.stderr = stderr;
        }
    }
}
