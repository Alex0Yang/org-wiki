;;; org-wiki.el --- Desktop wiki extension for org-mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2016  Caio Rodrigues Soares Silva

;; Author: Caio Rodrigues       <caiorss DOT rodrigues AT gmail DOT com>
;; Maintainer: Caio Rordrigues  <caiorss DOT rodrigues AT gmail DOT com>
;; Keywords: org-mode, wiki, notes, notebook
;; Version: 2.0
;; URL: https://www.github.com/caiorss/org-wiki'
;; Package-Requires: ((helm-core "2.0") (org "8") (cl-lib "0.5"))


;; This is free and unencumbered software released into the public domain.
;;
;; Anyone is free to copy, modify, publish, use, compile, sell, or
;; distribute this software, either in source code form or as a compiled
;; binary, for any purpose, commercial or non-commercial, and by any
;; means.
;;
;; In jurisdictions that recognize copyright laws, the author or authors
;; of this software dedicate any and all copyright interest in the
;; software to the public domain. We make this dedication for the benefit
;; of the public at large and to the detriment of our heirs and
;; successors. We intend this dedication to be an overt act of
;; relinquishment in perpetuity of all present and future rights to this
;; software under copyright law.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;; IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
;; OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
;; ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;; OTHER DEALINGS IN THE SOFTWARE.
;;
;; For more information, please refer to <http://unlicense.org/>

;;; Commentary:

;; Org-wiki is a org-mode extension that provides tools to manage and
;; build a desktop wiki where each wiki page is an org-mode file.
;;

;;; Code:
(require 'ox-html)
(require 'helm)
(require 'cl-lib)
(require 'easymenu)

(defgroup org-wiki nil
  "Org-wiki Settings"
  :group 'tools
  )

(defcustom org-wiki-location "~/org/wiki"
  "Org-wiki directory where all wiki pages files *.org are stored.
Default value ~/org/wiki."
  :type 'directory
  :group 'org-wiki
  )

(setq org-wiki-index-file-basename "index")

;; ------- Internal functions ------------ ;;
;; @SECTION: Internal functionsq
;;
(defun org-wiki--concat-path (base relpath)
  "Concat directory path (BASE) and a relative path (RELPATH)."
  (concat (file-name-as-directory base) relpath))

(defun org-wiki--unique (xs)
  "Remove repeated elements from a list XS.
Example:
> (org-wiki--unique '(x y a b 21 21 10 21 x y a ))
  (x y a b 21 10)"
  (let
    ((result nil))

    (dolist (x xs)
      (if (not (member x result))
          (push x result)
        ))
    (reverse result)))


(defun org-wiki--normalize-path (path)
  "Replace double slashes for a single slash and remove slash at the end of a PATH."
  (replace-regexp-in-string
   "//"
   "/"
   (replace-regexp-in-string "/$" "" (expand-file-name path))))

(defun  org-wiki--path-equal (p1 p2)
  "Test if paths P1 and P2 are equal."
  (equal (org-wiki--normalize-path p1) (org-wiki--normalize-path p2)))


(defun org-wiki--file->page (filename)
  "Get a wiki page name from a FILENAME.
Example:
ELISP> (file->org-wiki--page  \"Spanish.org\")
   \"Spanish\""
  (file-name-base filename))

(defun org-wiki--replace-extension (filename extension)
  "Replace a FILENAME extension by an new EXTENSION.
Example:
ELISP> (org-wiki/replace-extension \"file.org\" \"html\" )
       \"file.html\""
  (concat (car (split-string filename "\\."))
          "."
          extension
          ))


(defun org-wiki--page->file (pagename)
  "Get the corresponding wiki file (*.org) to the wiki PAGENAME.
Example:

ELISP> (org-wiki--page->file \"Linux\")
  \"~/org/wiki/Linux.org\""

  (concat (file-name-as-directory org-wiki-location)
          pagename
          ".org"
          ))

(defun org-wiki--buffer-file-in-wiki-p ()
  "Return true if current buffer file name is inside wiki directory."
  (file-exists-p

   (org-wiki--concat-path
    org-wiki-location
    (file-name-nondirectory (buffer-file-name)))))

(defun org-wiki--list-pages ()
  "Return a list containing all pages files *.org."
  (directory-files org-wiki-location))


(defun org-wiki--page->html-file (pagename)
  "Convert a wiki PAGENAME to html file name."
  (concat (file-name-as-directory (expand-file-name org-wiki-location))
          pagename
          ".html"
          ))

(defun org-wiki--page-files (&optional abspath)
  "Return a list containing all files in the wiki directory.

\(org-wiki--page-files &optional ABSPATH)

if abspath is null returns relative path, otherwise returns the absolute path.

Example:

ELISP> (remove-if-not #'file->org-wiki/page (org-wiki/page-files))
  (\"Abreviations_Slangs.wiki.org\" \"Android.wiki.org\" \"Bash_Script.wiki.org\")"

  (cl-remove-if-not
   (lambda (s)
     (let ((b (file-name-base s)))
       (not (or
             (string-prefix-p ".#" b)
             (string-suffix-p "~"  b )
             (string-prefix-p "#" b)
             (string-suffix-p "#" b)
           ))))
   (directory-files org-wiki-location abspath ".org")))


(defun org-wiki--page-list ()
  "Return a list containing all wiki pages.
Example: '(\"Linux\" \"BSD\" \"Bash\"  \"Binary_Files\")"
  (mapcar #'org-wiki--file->page (org-wiki--page-files)))


;; @REVIEW: Function for future use.
;;
;; (defun org-wiki--get-page (wikipage)
;;   (org-wiki--concat-path org-wiki-location
;;                     (replace-regexp-in-string "\s" "_"
;;                     (replace-regexp-in-string "%20" "_"
;;                      (concat wikipage ".org")))))


(defun org-wiki--assets-get-dir (pagename)
  "Get path to asset directory of given PAGENAME."
  (org-wiki--concat-path org-wiki-location pagename))


(defun org-wiki--assets-make-dir (pagename)
  "Create the asset directory of a wiki page (PAGENAME) if it doesn't exist.

Example: (org-wiki--assets-make-dir \"Bash\")

It will crate the directory ~/wiki-location/Bash/
corresponding to the file ~/wiki-location/Bash.org
if it doesn't exist yet."
  (let ((assets-dir (org-wiki--assets-get-dir pagename)))

    (if (not (file-exists-p assets-dir))
        (make-directory assets-dir t)
      )))


(defun org-wiki--assets-buffer-make-dir ()
  "Create asset directory of current buffer page if it doesn't exit."

  (if (org-wiki--buffer-file-in-wiki-p)

      (progn
        (org-wiki--assets-make-dir
         (file-name-base (buffer-file-name)))
        )
    (message "Error: Not in a wiki page.")))


;;=============== Org-mode custom protocol ===============;;
;;
;; @SECTION: Protocol

(defun org-wiki--org-link (path desc backend)
  "Creates an html org-wiki pages when  exporting to html.
Example: The hyperlink [[wiki:Linux][Dealing with Linux]]
will be exported to <a href='Linux.html'>Dealing with Linux</a>"
   (cl-case backend
     (html (format
            "<a href='%s.html'>%s</a>"
            path
            (or desc path)))))

(defun org-wiki--make-link (pagename)
  "Return a string containing a wiki link [[wiki:PAGENAME][PAGENAME]].
Example: if PAGENAME is Linux it will return [[wiki:Linux][Linux]]"
  (format "[[wiki:%s][%s]]" pagename pagename))

(defun org-wiki--open-page (pagename)
  "Opens a org-wiki page (PAGENAME) by name.

Example:  (org-wiki/open-page \"Linux\")
Will open the the wiki file Linux.org in
`org-wiki-location`"
  (find-file  (org-wiki--page->file pagename)))


(defun org-wiki--assets-get-file (pagename filename)
  "Return a path to an asset file FILENAME in given PAGENAME."
  (org-wiki--concat-path (org-wiki--assets-get-dir pagename) filename))

(defun org-wiki--assets-open-file-emacs (pagename filename)
  "Open an asset file FILENAME of a PAGENAME with Emacs.

Example: (org-wiki--assets-open-file-emacs \"Python\" \"example1.py\")
It will open the file <wiki path>/Python/example1.py related to the page Python.org."
  (find-file  (org-wiki--assets-get-file pagename filename)))


(defun org-wiki-xdg-open (filename)
  "Open a file FILENAME with default system application.
This function is operating system independent."
  (cl-case system-type

    ;;; Linux
    (gnu/linux      (let ((process-connection-type  nil))

                      (start-process
                          "proc"
                          nil
                         ;; Command
                          "xdg-open" (expand-file-name filename))))
    ;;; Free BSD OS
    (gnu/kfreebsd    (let ((process-connection-type  nil))

                       (start-process
                          "proc"
                          nil
                           ;; Command
                          "xdg-open" (expand-file-name filename))))

    ;; Mac OSX - (Not tested )
    (darwing        (start-process
                     "proc"
                     nil
                     ;; Command
                     "open" (concat  (expand-file-name filename))))

    ;; Windows 7, 8, 10 - Kernel NT
    (windows-nt   (start-process
                   "proc"
                   nil
                   ;; Command
                   "cmd"  "/C"  "start" "" (expand-file-name filename)
		     	    )

       ))) ;; End of org-wiki/xdg-open


(defun org-wiki--protocol-open-assets-with-sys (link)
  "Org-mode protocol handler to open an asset with default system app.
Example: it will turn a hyperlink LINK of syntax Blueprint;box1.dwg that
points to the file <org wiki location>/Blueprint/box1.dwg."

  (let* ((a     (split-string link ";"))
        (pagename  (car a))
        (filename  (cadr a))
        )
    (org-wiki-xdg-open
     (org-wiki--assets-get-file pagename filename))))


;;  @DONE: Implement html exporting to org-wiki asset files
;;
(defun org-wiki--asset-link (path desc backend)
  "Creates an html org-wiki pages html exporting."
  (let* ((a    (split-string path ";"))
        (page  (car a))
        (asset (cadr a))
        (file-path (concat page "/"  asset))
        )
   (cl-case backend
     (html (format
            "<a href='%s'>%s</a>"
            file-path
            (or desc asset))))))

;;; Custom Protocols
(add-hook 'org-mode-hook
          (lambda ()
            (org-add-link-type  "wiki"
                                #'org-wiki--open-page
                                #'org-wiki--org-link )
            (org-add-link-type  "wiki-asset-sys"
                                #'org-wiki--protocol-open-assets-with-sys
                                #'org-wiki--asset-link)))

(defun org-wiki--helm-selection (callback)
  "Open a helm menu to select the wiki page and invokes the CALLBACK function."
  (helm :sources `((
                      (name . "Wiki Pages")
                      (candidates . ,(org-wiki--unique (org-wiki--page-list)))
                      (action . ,callback)
                      ))))


(defun org-wiki--asset-page-files (pagename)
  "Get all asset files from a given PAGENAME."
  (org-wiki--assets-make-dir pagename)
  (directory-files (org-wiki--assets-get-dir pagename)))


(defun org-wiki--asset-helm-selection (pagename callback)
  "Higher order function to deal with page assets.

org-wiki-asset-helm-selection (PAGENAME CALLBACK)

This function opens a helm menu to select a wiki page and then
passes the result of selection to a callback function that takes
a asset file as argument.

Example: If the user selects the file freebsdref1.pdf it inserts the
file name at current point.

> (org-wiki--asset-helm-selection \"Linux\" (lambda (file) (insert file)))
  freebsdref1.pdf"

  (helm :sources `((
                      (name . "Wiki Pages")

                      (candidates . ,(org-wiki--asset-page-files pagename))

                      (action . ,callback)
                      ))))

;; ================= User Commands ================= ;;;
;;
;; @SECTION: User commands

(defun org-wiki-help ()
  "Show org-wiki commands."
  (interactive)
  (command-apropos "org-wiki-"))


(defun org-wiki-index ()
  "Open the index page: <org-wiki-location>/index.org.

   The file index.org is created if it doesn't exist."
  (interactive)
  (org-wiki--open-page org-wiki-index-file-basename))


(defun org-wiki-index-html ()
  "Open the Wiki (Index) in the default web browser."
  (interactive)
  (browse-url (concat "file://"
                      (org-wiki--page->html-file
                       org-wiki-index-file-basename))))

(defun org-wiki-index-frame ()
  "Open the index page in a new frame."
  (interactive)
  (with-selected-frame (make-frame)
    (org-wiki-index)))

(defun org-wiki-dired-all ()
  "Open the wiki directory in ‘dired-mode’ showing all files."
  (interactive)
  (dired org-wiki-location)
  (dired-hide-details-mode))

(defun org-wiki-dired ()
  "Open the wiki directory showing only the wiki pages."
  (interactive)
  (dired (org-wiki--concat-path org-wiki-location "*.org"))
  (dired-hide-details-mode))

(defun org-wiki-make-page ()
  "Create a new wiki page."
  (interactive)
  (find-file (org-wiki--page->file (read-string "Page Name: "))))

(defun org-wiki-asset-dired ()
  "Open the asset directory of current wiki page."
  (interactive)
  (let ((pagename (file-name-base (buffer-file-name))))
    (org-wiki--assets-make-dir pagename)
    (dired (org-wiki--assets-get-dir pagename))))

(defun org-wiki-asset-insert ()
  "Insert link wiki-asset-sys:<page>;<file> to an asset file of current page..
It inserts a link of type wiki-asset-sys:<Wiki-page>;<Asset-File>
Example:  [[wiki-asset-sys:Linux;LinuxManual.pdf]]"
  (interactive)

  (org-wiki--asset-helm-selection

   (file-name-base (buffer-file-name))

   (lambda (f)
     (insert (format "[[wiki-asset-sys:%s;%s][%s]]"
                     (file-name-base (buffer-file-name))
                     f
                     (read-string "Description: " f)
                     )))))

(defun org-wiki-asset-insert-file ()
  "Insert link file:<page>/<file> to asset file of current page at point.
Insert an asset file of current page at point providing a Helm completion.
Example: Linux/LinuxManual.pdf"
  (interactive)

  (let ((pagename (file-name-base (buffer-file-name))))
   (org-wiki--asset-helm-selection
    pagename
    (lambda (file)
      (insert (format "file:%s/%s"
                      pagename
                      file
                      ))))))

(defun org-wiki-asset-download-insert1 ()
  "Download a file from a URL in the clibpoard and inserts a link wiki-asset-sys:.
Note: This function is synchronous and blocks Emacs. If Emacs is stuck 
type C-g to cancel the download."
  (interactive)  
  (let*
      ((pagename (file-name-base (buffer-file-name)))
      ;; Get the URL suggestion from clibpoard
       (text (with-temp-buffer
              (clipboard-yank)
              (buffer-substring-no-properties (point-min)
                                              (point-max))))
       (url (read-string "Url: " text))
       (default-directory (org-wiki--assets-get-dir pagename))
       
       (output-file  (read-string "File name: "
                                  (car  (last (split-string url "/"))))))
      
    (org-wiki--assets-make-dir pagename)      
    (url-copy-file url output-file)    
    (insert (format "[[wiki-asset-sys:%s;%s][%s]]" pagename output-file output-file))))



(defun org-wiki-asset-download-insert2 ()
  "Download a file from a URL in the clibpoard and inserts a link file:<page>/<asset-file>.
Note: This function is synchronous and blocks Emacs. If Emacs is stuck 
type C-g to cancel the download."
  (interactive)  
  (let*
      ((pagename (file-name-base (buffer-file-name)))
      ;; Get the URL suggestion from clibpoard
       (text (with-temp-buffer
              (clipboard-yank)
              (buffer-substring-no-properties (point-min)
                                              (point-max))))
       (url (read-string "Url: " text))
       (default-directory (org-wiki--assets-get-dir pagename))
       
       (output-file  (read-string "File name: "
                                  (car  (last (split-string url "/"))))))
    
    (org-wiki--assets-make-dir pagename)      
    (url-copy-file url output-file)    
    (insert (format "file:%s/%s" pagename output-file ))))




(defun org-wiki-helm ()
  "Browser the wiki files using helm."
  (interactive)
  (org-wiki--helm-selection #'org-wiki--open-page))

(defun org-wiki-helm-read-only ()
  "Open wiki page in read-only mode."
  (interactive)
  (org-wiki--helm-selection (lambda (pagename)
                             (find-file-read-only
                              (org-wiki--page->file pagename)
                              ))))

(defun org-wiki-helm-frame ()
  "Browser the wiki files using helm and opens it in a new frame."
  (interactive)

  (org-wiki--helm-selection  (lambda (act)
                              (with-selected-frame (make-frame)
                                (org-wiki--open-page act)
                                ))))


;;  @TODO: Implement org-wiki/helm-html
;;
(defun org-wiki-helm-html ()
  "Browser the wiki files using helm."
  (interactive)
    (helm :sources `((
                      (name . "Wiki Pages")

                      (candidates . ,(org-wiki--unique (org-wiki--page-list)))

                      (action . org-wiki--open-page)
                      ))))


(defun org-wiki-close ()
  "Close all opened wiki pages buffer and save them."
  (interactive)

  (mapc (lambda (b)
          (when (and (buffer-file-name b) ;; test if is a buffer associated with file
                     (org-wiki--path-equal
                      org-wiki-location
                      (file-name-directory (buffer-file-name b)))
                       )
              (with-current-buffer b
                (save-buffer)
                (kill-this-buffer)
                )))
          (buffer-list))
  (message "All wiki files closed. Ok."))
  ;;
  ;; End of org-wiki/close

(defun org-wiki-insert ()
  "Insert a Wiki Page link at point."
  (interactive)
  (org-wiki--helm-selection
   (lambda (page) (insert (org-wiki--make-link page)))))


(defun org-wiki-html-page ()
  "Open the current wiki page in the browser.  It is created if it doesn't exist yet."
  (interactive)
  (let ((html-file   (org-wiki--replace-extension (buffer-file-name) "html")))
    (if (not (file-exists-p html-file))
        (org-html-export-to-html))
  (browse-url html-file)))

(defun org-wiki-html-page2 ()
  "Exports the current wiki page to html and opens it in the browser."
  (interactive)
  (org-html-export-to-html)
  (browse-url (org-wiki--replace-extension (buffer-file-name) "html")))

(defun org-wiki-search ()
  "Search all wiki pages that contains a pattern (regexp or name)."
  (interactive)
  (rgrep (read-string "org-wiki - Search for: ")
         "*.org"
         org-wiki-location
         nil))

(defun org-wiki-open ()
  "Opens the wiki repository with system's default file manager."
  (interactive)
  (org-wiki-xdg-open org-wiki-location))

(defun org-wiki-asset-open ()
  "Open asset directory of current page with system's default file manager."
  (interactive)
  (org-wiki--assets-buffer-make-dir)
  (org-wiki-xdg-open (file-name-base (buffer-file-name))))

(defun org-wiki-assets-helm ()
  "Open the assets directory of a wiki page."
  (interactive)
  (org-wiki--helm-selection
   (lambda (page)
     (org-wiki--assets-make-dir page)
     (dired (org-wiki--assets-get-dir page)))))

(defun org-wiki-export-html-sync ()
  "Export all pages to html in synchronous mode."
  (interactive)
  (let ((org-html-htmlize-output-type 'css)
        (org-html-htmlize-font-prefix "org-")
        )
    (org-publish
     `("html"
       :base-directory       ,org-wiki-location
       :base-extension        "org"
       :publishing-directory  ,org-wiki-location
       :publishing-function    org-html-publish-to-html
       )
     t
     )))

(defun org-wiki-export-html ()
  "Export all pages to html.
Note: This function doesn't freeze Emacs since it starts another Emacs process."
  (interactive)
  (compile (mapconcat 'identity
                      `("emacs"
                        "--batch"
                        "-l" ,user-init-file
                        "-f" "org-wiki-export-html-sync"
                        "--kill"
                        )
                      " "
                      )))

(defun org-wiki-make-menu ()
  "Optional command to build an utility menu."
  (easy-menu-define org-wik-menu global-map "Utils"
    
    `("org-wiki"
      ("Main"
       ["Go to Index page / M-x org-wiki-index" (org-wiki-index)]      
       ["Browse page / M-x org-wiki-helm" (org-wiki-helm)]
       ["Browse page in other frame / M-x org-wiki-helm-frame" (org-wiki-helm-frame)]
       ["Browse pages in read-only mode / M-x org-wiki-helm-read-only" (org-wiki-helm-read-only)]
       ["Open org-wiki directory / M-x org-wiki-dired" (org-wiki-dired)]
       ["Close all pages / M-x org-wiki-close" (org-wiki-close)]
       )
      ["---"  nil]
      ("Page Commands"
        ["Browse current page asset directory.\nM-x org-wiki-asset-dired" (org-wiki-asset-dired)]
        ["Insert a link to a wiki pagenM-x org-wiki-insert" (org-wiki-insert)]
        ["Insert a link of type wiki-asset-sys at point.\nM-x org-wiki-asset-insert"
        (org-wiki-asset-insert)]
        ["Insert a link of type file:<page>/<asset> at point.\nM-x org-wiki-asset-insert-file"
         (org-wiki-asset-insert-file)
         ]
        ["Download an asset file and insert a wiki-asset-sys link at point.\nM-x org-wiki-asset-download-insert1"
         (org-wiki-asset-download-insert1)
         ]
        ["Download an asset file and insert a link at point of type file:<page>/<file.pdf>.\nM-x org-wiki-asset-download-insert2"
         (org-wiki-asset-download-insert2)
         ]        
        
        )             
       ["---"  nil]
       ("Org-mode"
       ["Filter headings     / M-x helm-org-in-buffer-headings" (helm-org-in-buffer-headings)]
       ["Hem occur           / M-x helm-occur"                   (helm-occur)]
       ["Toggle Read only    / M-x read-only-mode"               (read-only-mode 'toggle)]
       ["Toggle Images       / M-x org-toggle-inline-images"     (org-toggle-inline-images)]
       ["Toggle Link display / M-x org-toggle-link-display"      (org-toggle-link-display)]
      ))))


(provide 'org-wiki)
;;; org-wiki.el ends here
