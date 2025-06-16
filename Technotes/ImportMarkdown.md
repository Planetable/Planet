## Import Markdown Files to Planet


### Overview
Choose markdown files via a menu bar option to import as articles for selected planet.

### Possible Inline Resources
When importing markdown files, the app needs to handle various types of inline resources that may be referenced:

| Resource Type | Example | Notes |
|---------------|---------|-------|
| Remote URL | `![image](https://example.com/image.png)` | Direct HTTP/HTTPS links |
| Local Relative Path | `![image](./assets/image.png)` | Relative to markdown file location |
| Local Absolute Path (macOS/Linux) | `![image](/Users/kai/docs/image.png)` | Unix-style absolute paths |
| Local Absolute Path (Windows) | `![image](C:\Users\kai\docs\image.png)` | Windows drive letters and backslashes |
| Base64 Encoded | `![image](data:image/png;base64,iVBORw0KGgo...)` | Embedded data URIs |
| Reference Style Links | `![image][ref1]` with `[ref1]: ./image.png` | Markdown reference definitions |
| HTML img/video/audio tags | `<img src="./image.png">` | HTML elements in markdown |
| File Protocol URLs | `![file](file:///Users/kai/docs/file.txt)` | Local file:// URLs |
| Network Shares (UNC) | `![image](\\server\share\image.png)` | Windows UNC paths |
| Network Shares (SMB) | `![image](smb://server/share/image.png)` | macOS/Linux network protocols |
| User Home Directory | `![image](~/Documents/image.png)` | Tilde expansion on Unix systems |
| Environment Variables | `![image]($HOME/docs/image.png)` | Variable substitution |
| Symbolic Links | `![image](./symlink-to-image.png)` | Links to actual files/directories |
| URL-encoded Paths | `![image](./folder%20with%20spaces/image.png)` | Encoded special characters |
| Query Parameters | `![image](https://api.example.com/image?id=123&size=large)` | URLs with parameters |
| Fragment Identifiers | `[link](./doc.md#section-name)` | Links to document sections |
| FTP/SFTP URLs | `![file](ftp://server.com/file.txt)` | File transfer protocols |
| Blob URLs | `![image](blob:https://example.com/uuid)` | Browser-generated blob URLs |
| Special Characters | `![image](./файл.png)` | Unicode/international filenames |

### Import Process: Select Files > Validate > Choose Planet > Import
1. A multi-step import window will be provided to open target markdown files. 
2. The app will parse each file to identify related inline resources based on the types listed above. There will be a question mark if it has invalid resources, click to show details which we will talk about below. The import process will mainly focus on local inline resources as they will be the attachments for the imported article.
3. Click 'Next' to ignore these invalid resources and continue the import process if the user chooses to do so.
4. The app will prompt to choose a planet to import.

### Validate and Fix Inline Resources Manually
1. Click on the question mark icon next to each file with invalid resources to see a detailed list of issues in a validation view, then fix them manually if needed.
2. The validation view should be a modal dialog that allows users to:
   - View the list of invalid resources.
   - Click on each resource to relocate it.
   - Non-destructive: users can close the dialog without making changes until they choose to update.
3. Fixed files will be marked as valid.
