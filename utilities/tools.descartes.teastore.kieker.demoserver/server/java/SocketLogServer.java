import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;

/**.
 * Receives the contents of the Kieker logs (File Transfer)
 *
 * @author Gines Moratalla
 *
 */
public class SocketLogServer {

  private static final int PORT = 3001;
  private static final String LOG_DIRECTORY = "/opt/kieker/java/kieker-logs";
  
  public static void main(String[] args) {

    File logDir = new File(LOG_DIRECTORY);
    if (!logDir.exists()) {
      System.out.println("kieker-logs directory does NOT exist");
      logDir.mkdir();
    } else System.out.println("kieker-logs directory exists");

    while (true) {
        try (ServerSocket serverSocket = new ServerSocket(PORT)) {
            System.out.println("Server listening on port " + PORT);

            while (true) {

                try (Socket clientSocket = serverSocket.accept();
                     BufferedInputStream bufferInputStream = new BufferedInputStream(clientSocket.getInputStream());
                     DataInputStream dataInputStream = new DataInputStream(bufferInputStream))
                {
                  System.out.println("Client connected");

                  int fileCount = dataInputStream.readInt();
                  File[] files = new File[fileCount];
                  
                  try {

                    for(int i = 0; i < fileCount; i++) {
                      long fileLength = dataInputStream.readLong();
                      String fileName = dataInputStream.readUTF();

                      files[i] = new File(logDir + "/" + fileName);

                      FileOutputStream fileOutputStream = new FileOutputStream(files[i], false);
                      BufferedOutputStream bufferOutputStream = new BufferedOutputStream(fileOutputStream);

                      for(int j = 0; j < fileLength; j++) bufferOutputStream.write(bufferInputStream.read());
                      bufferOutputStream.close();

                    }
                    bufferInputStream.close();
                    System.out.println("All files received successfully");

                  } catch (IOException e) {
                    System.err.println("Error reading files: " + e.getMessage());
                  }

                } catch (IOException e1) {
                    System.err.println("Error handling client: " + e1.getMessage());
                }
            }

        // Try restarting to server again after 5 seconds
        } catch (IOException e2) {
            System.err.println("Error starting server: " + e2.getMessage());
            try {
                Thread.sleep(5000);
            } catch (InterruptedException e3) {
                System.err.println("Server retry interrupted: " + e3.getMessage());
                break;
            }
        }
    }
  }
}

