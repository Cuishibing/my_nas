package cui.shibing.core.common;

public class Md5Util {
    public static String getMd5(String filePath) {
        try (java.io.FileInputStream fis = new java.io.FileInputStream(filePath)) {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("MD5");
            byte[] buffer = new byte[8192];
            int length;
            while ((length = fis.read(buffer)) != -1) {
                md.update(buffer, 0, length);
            }
            
            byte[] md5Bytes = md.digest();
            StringBuilder sb = new StringBuilder();
            for (byte b : md5Bytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("计算MD5失败", e);
        }
    }
}
