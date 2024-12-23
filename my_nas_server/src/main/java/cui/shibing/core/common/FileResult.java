package cui.shibing.core.common;

public class FileResult {
    private String filePath;

    private String contentType;

    public FileResult(String filePath) {
        this.filePath = filePath;

        String suffix = filePath.substring(filePath.lastIndexOf(".") + 1).toLowerCase();
        switch (suffix) {
            case "jpg":
            case "jpeg":
                contentType = "image/jpeg";
                break;
            case "png":
                contentType = "image/png"; 
                break;
            case "gif":
                contentType = "image/gif";
                break;
            case "mp3":
                contentType = "audio/mpeg";
                break;
            case "mp4":
                contentType = "video/mp4";
                break;
            case "pdf":
                contentType = "application/pdf";
                break;
            default:
                contentType = "application/octet-stream";
        }
    }

    public String getFilePath() {
        return filePath;
    }

    public String getContentType() {
        return contentType;
    }
}
