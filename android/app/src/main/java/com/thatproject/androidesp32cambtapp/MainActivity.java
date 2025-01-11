package com.thatproject.androidesp32cambtapp;

import android.media.MediaScannerConnection;
import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "com.thatproject.androidesp32cambtapp/mediaScanner";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Set up the MethodChannel for Flutter communication
        new MethodChannel(getFlutterEngine().getDartExecutor(), CHANNEL).setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("rescanMedia")) {
                        String path = call.argument("path");
                        triggerMediaScan(path);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                }
        );
    }

    private void triggerMediaScan(String path) {
        MediaScannerConnection.scanFile(this, new String[]{path}, null, (filePath, uri) -> {
            System.out.println("Scanned " + filePath + ":");
            System.out.println("-> uri=" + uri);
        });
    }
}
