package com.seamlessconnect;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

public class MainActivity extends Activity {

    private TextView tvFtpStatus;
    private TextView tvAdbStatus;
    private TextView tvNetworkDetails;
    private Button btnStartService;
    private Button btnStopService;
    private Button btnRescanMedia;
    private Button btnRefreshAll;
    private Button btnAddMacDialog;
    private LinearLayout containerClients;
    private LinearLayout containerAuthorized;
    private TextView tvNoClients;
    private TextView tvNoAuthorized;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        initViews();
        setupListeners();
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshAllAsync();
    }

    private void initViews() {
        tvFtpStatus = findViewById(R.id.tv_ftp_status);
        tvAdbStatus = findViewById(R.id.tv_adb_status);
        tvNetworkDetails = findViewById(R.id.tv_network_details);
        btnStartService = findViewById(R.id.btn_start_service);
        btnStopService = findViewById(R.id.btn_stop_service);
        btnRescanMedia = findViewById(R.id.btn_rescan_media);
        btnRefreshAll = findViewById(R.id.btn_refresh_all);
        btnAddMacDialog = findViewById(R.id.btn_add_mac_dialog);
        containerClients = findViewById(R.id.container_clients);
        containerAuthorized = findViewById(R.id.container_authorized);
        tvNoClients = findViewById(R.id.tv_no_clients);
        tvNoAuthorized = findViewById(R.id.tv_no_authorized);
    }

    private void setupListeners() {
        btnRefreshAll.setOnClickListener(v -> refreshAllAsync());

        btnStartService.setOnClickListener(v -> {
            btnStartService.setEnabled(false);
            new Thread(() -> {
                boolean ok = NetworkHelper.startFtpServer();
                mainHandler.post(() -> {
                    btnStartService.setEnabled(true);
                    Toast.makeText(this, ok ? "FTP Server Started" : "Failed to start FTP", Toast.LENGTH_SHORT).show();
                    refreshAllAsync();
                });
            }).start();
        });

        btnStopService.setOnClickListener(v -> {
            btnStopService.setEnabled(false);
            new Thread(() -> {
                boolean ok = NetworkHelper.stopFtpServer();
                mainHandler.post(() -> {
                    btnStopService.setEnabled(true);
                    Toast.makeText(this, ok ? "FTP Server Stopped" : "Failed to stop FTP", Toast.LENGTH_SHORT).show();
                    refreshAllAsync();
                });
            }).start();
        });

        btnRescanMedia.setOnClickListener(v -> {
            btnRescanMedia.setEnabled(false);
            new Thread(() -> {
                boolean ok = NetworkHelper.triggerMediaScan();
                mainHandler.post(() -> {
                    btnRescanMedia.setEnabled(true);
                    Toast.makeText(this, ok ? "Media library rescan triggered" : "Media scan failed", Toast.LENGTH_SHORT).show();
                });
            }).start();
        });

        btnAddMacDialog.setOnClickListener(v -> showAddMacDialog(null));
    }

    private void refreshAllAsync() {
        new Thread(() -> {
            NetworkHelper.ServiceState state = NetworkHelper.getServiceState();
            List<DeviceManager.Device> authorized = DeviceManager.loadAuthorizedDevices();
            List<NetworkHelper.HotspotClient> clients = NetworkHelper.getConnectedClients(authorized);

            mainHandler.post(() -> {
                updateStateUi(state);
                updateAuthorizedUi(authorized);
                updateClientsUi(clients, authorized);
            });
        }).start();
    }

    private void updateStateUi(NetworkHelper.ServiceState state) {
        if (state.isFtpRunning) {
            tvFtpStatus.setText("FTP Server: RUNNING (Port " + state.ftpPort + ")");
            tvFtpStatus.setTextColor(Color.parseColor("#4CAF50"));
        } else {
            tvFtpStatus.setText("FTP Server: STOPPED");
            tvFtpStatus.setTextColor(Color.parseColor("#FB8C00"));
        }

        tvAdbStatus.setText("Wireless ADB: Port " + state.adbPort + " (Active)");
        tvNetworkDetails.setText("Hotspot IP: " + state.hotspotIp + " | Interface: " + state.iface);
    }

    private void updateAuthorizedUi(List<DeviceManager.Device> devices) {
        containerAuthorized.removeAllViews();
        if (devices.isEmpty()) {
            tvNoAuthorized.setVisibility(View.VISIBLE);
        } else {
            tvNoAuthorized.setVisibility(View.GONE);
            LayoutInflater inflater = LayoutInflater.from(this);
            for (DeviceManager.Device d : devices) {
                View itemView = inflater.inflate(R.layout.item_device, containerAuthorized, false);
                TextView tvName = itemView.findViewById(R.id.tv_device_name);
                TextView tvMac = itemView.findViewById(R.id.tv_device_mac);
                Button btnDelete = itemView.findViewById(R.id.btn_delete_device);

                tvName.setText(d.name);
                tvMac.setText(d.mac);

                btnDelete.setOnClickListener(v -> {
                    new AlertDialog.Builder(this)
                            .setTitle("Remove Device?")
                            .setMessage("Remove " + d.name + " (" + d.mac + ") from authorized devices? It will no longer be allowed to connect to FTP.")
                            .setPositiveButton("Remove", (dialog, which) -> {
                                new Thread(() -> {
                                    DeviceManager.removeDevice(d.mac);
                                    mainHandler.post(this::refreshAllAsync);
                                }).start();
                            })
                            .setNegativeButton("Cancel", null)
                            .show();
                });

                containerAuthorized.addView(itemView);
            }
        }
    }

    private void updateClientsUi(List<NetworkHelper.HotspotClient> clients, List<DeviceManager.Device> authorized) {
        containerClients.removeAllViews();
        if (clients.isEmpty()) {
            tvNoClients.setVisibility(View.VISIBLE);
        } else {
            tvNoClients.setVisibility(View.GONE);
            LayoutInflater inflater = LayoutInflater.from(this);
            for (NetworkHelper.HotspotClient c : clients) {
                View itemView = inflater.inflate(R.layout.item_client, containerClients, false);
                TextView tvIp = itemView.findViewById(R.id.tv_client_ip);
                TextView tvMac = itemView.findViewById(R.id.tv_client_mac);
                TextView tvStatus = itemView.findViewById(R.id.tv_client_status);
                Button btnAuth = itemView.findViewById(R.id.btn_auth_client);

                tvIp.setText(c.ip);
                tvMac.setText(c.mac);
                tvStatus.setText(c.status + " • " + c.iface);

                if (c.isAuthorized) {
                    btnAuth.setText("Authorized ✓");
                    btnAuth.setBackgroundColor(Color.parseColor("#388E3C"));
                    btnAuth.setEnabled(false);
                } else {
                    btnAuth.setText("+ Authorize");
                    btnAuth.setBackgroundColor(Color.parseColor("#1E88E5"));
                    btnAuth.setEnabled(true);
                    btnAuth.setOnClickListener(v -> showAddMacDialog(c.mac));
                }

                containerClients.addView(itemView);
            }
        }
    }

    private void showAddMacDialog(String prefillMac) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle(prefillMac != null ? "Authorize Connected Device" : "Authorize New MAC");

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(48, 24, 48, 24);

        final EditText etName = new EditText(this);
        etName.setHint("Device Name (e.g. Work Laptop)");
        layout.addView(etName);

        final EditText etMac = new EditText(this);
        etMac.setHint("Hardware MAC (e.g. aa:bb:cc:dd:ee:ff)");
        if (prefillMac != null) {
            etMac.setText(prefillMac);
            etMac.setEnabled(false);
            etName.requestFocus();
        }
        layout.addView(etMac);

        builder.setView(layout);

        builder.setPositiveButton("Authorize", (dialog, which) -> {
            String name = etName.getText().toString().trim();
            String mac = etMac.getText().toString().trim().toLowerCase();

            if (name.isEmpty()) name = "Authorized Laptop";
            if (!mac.matches("^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$")) {
                Toast.makeText(this, "Invalid MAC address format!", Toast.LENGTH_LONG).show();
                return;
            }

            final String finalMac = mac;
            final String finalName = name;
            new Thread(() -> {
                boolean ok = DeviceManager.addDevice(finalMac, finalName);
                mainHandler.post(() -> {
                    Toast.makeText(this, ok ? "Device Authorized!" : "Failed to save device", Toast.LENGTH_SHORT).show();
                    refreshAllAsync();
                });
            }).start();
        });

        builder.setNegativeButton("Cancel", null);
        builder.show();
    }
}
