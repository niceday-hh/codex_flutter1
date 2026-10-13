import java.io.InputStream;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.cert.Certificate;
import java.util.Enumeration;
import java.util.HexFormat;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

/** Independently checks traditional APK/JAR certificates, including large assets. */
class VerifyApkCertificates {
    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("APK and expected certificate SHA256 required");
        String expected = args[1].toLowerCase();
        int checked = 0;
        boolean certificateBlock = false;
        byte[] buffer = new byte[65536];
        try (JarFile apk = new JarFile(Path.of(args[0]).toFile(), true)) {
            Enumeration<JarEntry> entries = apk.entries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                String name = entry.getName();
                if (name.matches("META-INF/[^/]+\\.(RSA|EC|DSA)")) certificateBlock = true;
                if (entry.isDirectory() || name.startsWith("META-INF/")) continue;
                // Reading every byte triggers JAR signature verification for this entry.
                try (InputStream input = apk.getInputStream(entry)) {
                    while (input.read(buffer) != -1) { /* bounded buffer, even for the 227 MB model */ }
                }
                Certificate[] certificates = entry.getCertificates();
                if (certificates == null || certificates.length == 0)
                    throw new SecurityException("No V1 certificate on APK entry: " + name);
                String actual = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(certificates[0].getEncoded()));
                if (!actual.equals(expected)) throw new SecurityException("Unexpected signer on APK entry: " + name);
                checked++;
            }
            if (!certificateBlock || checked == 0) throw new SecurityException("APK contains no traditional signing certificate");
        }
        System.out.println("Verified V1 certificate and signed contents for " + checked + " APK entries; signer SHA256=" + expected);
    }
}
