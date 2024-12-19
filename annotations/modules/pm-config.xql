
xquery version "3.1";

module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config";

import module namespace pm-annotations-web="http://www.tei-c.org/pm/models/annotations/web/module" at "../transform/annotations-web-module.xql";
import module namespace pm-annotations-print="http://www.tei-c.org/pm/models/annotations/print/module" at "../transform/annotations-print-module.xql";
import module namespace pm-annotations-latex="http://www.tei-c.org/pm/models/annotations/latex/module" at "../transform/annotations-latex-module.xql";
import module namespace pm-annotations-epub="http://www.tei-c.org/pm/models/annotations/epub/module" at "../transform/annotations-epub-module.xql";
import module namespace pm-annotations-fo="http://www.tei-c.org/pm/models/annotations/fo/module" at "../transform/annotations-fo-module.xql";
import module namespace pm-FPB-web="http://www.tei-c.org/pm/models/FPB/web/module" at "../transform/FPB-web-module.xql";
import module namespace pm-FPB-print="http://www.tei-c.org/pm/models/FPB/print/module" at "../transform/FPB-print-module.xql";
import module namespace pm-FPB-latex="http://www.tei-c.org/pm/models/FPB/latex/module" at "../transform/FPB-latex-module.xql";
import module namespace pm-FPB-epub="http://www.tei-c.org/pm/models/FPB/epub/module" at "../transform/FPB-epub-module.xql";
import module namespace pm-FPB-fo="http://www.tei-c.org/pm/models/FPB/fo/module" at "../transform/FPB-fo-module.xql";
import module namespace pm-docx-tei="http://www.tei-c.org/pm/models/docx/tei/module" at "../transform/docx-tei-module.xql";

declare variable $pm-config:web-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "annotations.odd" return pm-annotations-web:transform($xml, $parameters)
case "FPB.odd" return pm-FPB-web:transform($xml, $parameters)
    default return pm-annotations-web:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:print-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "annotations.odd" return pm-annotations-print:transform($xml, $parameters)
case "FPB.odd" return pm-FPB-print:transform($xml, $parameters)
    default return pm-annotations-print:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:latex-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "annotations.odd" return pm-annotations-latex:transform($xml, $parameters)
case "FPB.odd" return pm-FPB-latex:transform($xml, $parameters)
    default return pm-annotations-latex:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:epub-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "annotations.odd" return pm-annotations-epub:transform($xml, $parameters)
case "FPB.odd" return pm-FPB-epub:transform($xml, $parameters)
    default return pm-annotations-epub:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:fo-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "annotations.odd" return pm-annotations-fo:transform($xml, $parameters)
case "FPB.odd" return pm-FPB-fo:transform($xml, $parameters)
    default return pm-annotations-fo:transform($xml, $parameters)
            
    
};
            


declare variable $pm-config:tei-transform := function($xml as node()*, $parameters as map(*)?, $odd as xs:string?) {
    switch ($odd)
    case "docx.odd" return pm-docx-tei:transform($xml, $parameters)
    default return error(QName("http://www.tei-c.org/tei-simple/pm-config", "error"), "No default ODD found for output mode tei")
            
    
};
            
    