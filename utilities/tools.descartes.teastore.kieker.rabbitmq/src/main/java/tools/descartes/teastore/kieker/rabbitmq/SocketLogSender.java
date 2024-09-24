package tools.descartes.teastore.kieker.rabbitmq;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FilenameFilter;
import java.io.IOException;
import java.net.Socket;
import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * Sends the Kieker logs through a Socket connection.
 *
 * @author Gines Moratalla
 *
 */
public class SocketLogSender implements Runnable {

    private Socket serverSocket;
    private final String serverAddress = "socket-log-server";
    private final int PORT = 3001;
    private String LOG_DIRECTORY = "apache-tomcat-8.5.24/webapps/logs/";

    // Logging purposes
    private SimpleDateFormat formatter = new SimpleDateFormat("dd/MM/yyyy HH:mm:ss");

    @Override
    public void run() {
        while (true) {
            try {

                serverSocket = new Socket(serverAddress, PORT);
                System.out.println("[" + formatter.format(new Date())
                                   + "] TRACE ANALYSIS LOG: Succesfully connected to server at "
                                   + serverAddress + ":" + PORT);

                BufferedOutputStream bufferOutputStream = new BufferedOutputStream(serverSocket.getOutputStream());
                DataOutputStream dataOutputStream = new DataOutputStream(bufferOutputStream);

                while (true) {

                    File outerDir = new File(LOG_DIRECTORY);
                    File directory = new File(LOG_DIRECTORY + findKiekerLogs(outerDir, "kieker-"));

                    File[] files = directory.listFiles();
                    if (files == null || files.length == 0) {
                        System.out.println("[" + formatter.format(new Date())
                                           + "] TRACE ANALYSIS LOG: Files not found in directory: " + directory);
                        continue;
                    }

                    dataOutputStream.writeInt(files.length);

                    try {
                        for (File file : files) {
                            long length = file.length();
                            dataOutputStream.writeLong(length);

                            String name = file.getName();
                            dataOutputStream.writeUTF(name);

                            FileInputStream fileInputStream = new FileInputStream(file);
                            BufferedInputStream bufferInputStream = new BufferedInputStream(fileInputStream);

                            int _byte = 0;
                            while ((_byte = bufferInputStream.read()) != -1) {
                                bufferOutputStream.write(_byte);
                            }

                            bufferInputStream.close();

                        }
                        System.out.println("[" + formatter.format(new Date())
                                           + "] TRACE ANALYSIS LOG: Succesfully sent files");
                        dataOutputStream.flush();
                        bufferOutputStream.flush();

                    } catch (IOException e) {
                        System.err.println("[" + formatter.format(new Date())
                                           + "] TRACE ANALYSIS LOG: Error sending files: " + e.getMessage());
                    }
                    // Sleep 5 seconds before sending the files again
                    try {
                        Thread.sleep(5000);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                }
                // Retry Connection to Socket Server
            } catch (IOException e) {
                System.err.println("[" + formatter.format(new Date())
                                   + "] TRACE ANALYSIS LOG: Error connecting to the server (Trying Again in 5 Seconds): "
                                   + e.getMessage());
                try {
                    Thread.sleep(5000);
                } catch (InterruptedException e1) {
                    e1.printStackTrace();
                }
            }
        }
    }

    /*
     *
     * Finds the container path where Kieker's Logs are being stored
     *
     * @return the Path kor kieker-* directory
     *
     */
    private String findKiekerLogs(File dir, String startPrefix) {

        if (!dir.isDirectory()) {
            System.out.println("[" + formatter.format(new Date())
                               + "] TRACE ANALYSIS LOG: Directory not found");
            return null;
        }

        File[] files = dir.listFiles(new FilenameFilter() {
            public boolean accept(File dir, String name) {
                return name.startsWith(startPrefix);
            }
        });
        return (files != null && files.length > 0) ? files[0].getName() : null;
    }
}
