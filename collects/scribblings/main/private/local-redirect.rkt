#lang at-exp racket/base
(require scribble/core
         racket/serialize
         racket/class
         racket/match
         setup/dirs
         net/url)

(provide make-local-redirect)

(define rewrite-code
  @string-append|{
    function bsearch(str, start, end) {
       if (start >= end)
         return false;
       else {
         var mid = Math.floor((start + end) / 2);
         if (link_targets[mid][0] == str)
           return mid;
         else if (link_targets[mid][0] < str)
           return bsearch(str, mid+1, end);
         else
           return bsearch(str, start, mid);
       }
    }

    function convert_all_links() {
       var elements = document.getElementsByClassName("Sq");
       for (var i = 0; i < elements.length; i++) {
         var elem = elements[i];
         var n = elem.href.match(/tag=[^&]*/);
         if (n) {
           var pos = bsearch(decodeURIComponent(n[0].substring(4)), 0, link_targets.length);
           if (pos) {
             elem.href = link_targets[pos][1];
           }
         }
       }
    }

    AddOnLoad(convert_all_links);
  }|)

(define (make-local-redirect user?)
  (make-render-element
   #f
   null
   (lambda (renderer p ri)
     (define keys (resolve-get-keys #f ri (lambda (v) #t)))
     (define (target? v) (and (vector? v) (= 5 (vector-length v))))
     (define dest (build-path (send renderer get-dest-directory #t) 
                              "local-redirect.js"))
     (define db
       (sort (for/list ([k (in-list keys)]
                        #:when (tag? k)
                        #:when (target? (resolve-get p ri k)))
               (list (send renderer tag->query-string k)
                     (send renderer tag->url-string ri k #:absolute? user?)))
             string<?
             #:key car))
     (call-with-output-file*
      dest
      #:exists 'truncate/replace
      (lambda (o)
        (fprintf o "// Autogenerated by `scribblings/main/private/local-redirect'\n")
        (fprintf o "//  This script is included by generated documentation to rewrite\n")
        (fprintf o "//  links expressed as tag queries into local-filesystem links.\n")
        (newline o)
        (fprintf o "var link_targets = [")
        (for ([e (in-list db)]
              [i (in-naturals)])
          (fprintf o (if (zero? i) "\n" ",\n"))
          (fprintf o " [~s, ~s]" (car e) (cadr e)))
        (fprintf o "];\n\n")
        (fprintf o rewrite-code))))))
