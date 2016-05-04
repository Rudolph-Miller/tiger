%{

#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include "util.h"
#include "tokens.h"
#include "errormsg.h"

int charPos = 1;

int commentNesting = 0;

const int INITIAL_BUFFER_LENGTH = 32;
char *string_buffer;
unsigned int string_buffer_capacity;

void init_string_buffer(void) {
  string_buffer = checked_malloc(INITIAL_BUFFER_LENGTH);
  string_buffer[0] = 0;
  string_buffer_capacity = INITIAL_BUFFER_LENGTH;
}

static void append_char_to_stringbuffer(char ch) {
  size_t new_length = strlen(string_buffer) + 1;
  if (new_length == string_buffer_capacity)
  {
    char *temp;

    string_buffer_capacity *= 2;
    temp = checked_malloc(string_buffer_capacity);
    memcpy(temp, string_buffer, new_length);
    free(string_buffer);
    string_buffer = temp;
  }
  string_buffer[new_length - 1] = ch;
  string_buffer[new_length] = 0;
}

int yywrap(void) {
  charPos = 1;
  return 1;
}

void adjust(void) {
  EM_tokPos = charPos;
  charPos += yyleng;
}

%}

%option nounput
%option noinput

%x COMMENT STRING_STATE

%%

[ \r\t] {adjust(); continue;}

<INITIAL,COMMENT>\n {
  adjust();
  EM_newline();
  continue;
}

while     {adjust(); return WHILE;}
for       {adjust(); return FOR;}
to        {adjust(); return TO;}
break     {adjust(); return BREAK;}
let       {adjust(); return LET;}
in        {adjust(); return IN;}
end       {adjust(); return END;}
function  {adjust(); return FUNCTION;}
var       {adjust(); return VAR;}
type      {adjust(); return TYPE;}
array     {adjust(); return ARRAY;}
if        {adjust(); return IF;}
then      {adjust(); return THEN;}
else      {adjust(); return ELSE;}
do        {adjust(); return DO;}
of        {adjust(); return OF;}
nil       {adjust(); return NIL;}

","   {adjust(); return COMMA;}
":"   {adjust(); return COLON;}
";"   {adjust(); return SEMICOLON;}
"("   {adjust(); return LPAREN;}
")"   {adjust(); return RPAREN;}
"["   {adjust(); return LBRACK;}
"]"   {adjust(); return RBRACK;}
"{"   {adjust(); return LBRACE;}
"}"   {adjust(); return RBRACE;}
"."   {adjust(); return DOT;}
"+"   {adjust(); return PLUS;}
"-"   {adjust(); return MINUS;}
"*"   {adjust(); return TIMES;}
"/"   {adjust(); return DIVIDE;}
"="   {adjust(); return EQ;}
"<>"  {adjust(); return NEQ;}
"<"   {adjust(); return LT;}
"<="  {adjust(); return LE;}
">"   {adjust(); return GT;}
">="  {adjust(); return GE;}
"&"   {adjust(); return AND;}
"|"   {adjust(); return OR;}
":="  {adjust(); return ASSIGN;}

[a-zA-Z]+[_0-9a-zA-Z]* {
  adjust();
  yylval.sval = strdup(yytext);
  return ID;
}

[0-9]+ {
  adjust();
  yylval.ival = atoi(yytext);
  return INT;
}

\" {
  adjust();
  init_string_buffer();
  BEGIN(STRING_STATE);
}

"/*" {
  adjust();
  commentNesting++;
  BEGIN(COMMENT);
}

"*/" {
  adjust();
  EM_error(EM_tokPos, "Found closing comment tag while no comment was open!");
  yyterminate();
}

. {
  adjust();
  EM_error(EM_tokPos, "Illegal token!");
  yyterminate();
}

<STRING_STATE>{
  \" {
    adjust();
    BEGIN(INITIAL);
    yylval.sval = strdup(string_buffer);
    return STRING;
  }

  \n {
    adjust();
    EM_error(EM_tokPos, "Unterminated string constant!");
    yyterminate();
  }

  \\[0-9]{3} {
    adjust();
    int result;
    sscanf(yytext + 1, "%d", &result);
    if (result > 0xff) {
      EM_error(EM_tokPos, "ASCII decimal value out of bounds!");
      yyterminate();
    }
    append_char_to_stringbuffer(result);
  }

  \\[0-9]+ {
    adjust();
    EM_error(EM_tokPos, "Bad escape sequence!");
    yyterminate();
  }

  \\n {
    adjust();
    append_char_to_stringbuffer('\n');
  }

  \\t {
    adjust();
    append_char_to_stringbuffer('\t');
  }

  "\^"[@A-Z\[\\\]\^_?] {
    adjust();
    append_char_to_stringbuffer(yytext[1]-'@');
  }

  "\\\"" {
    adjust();
    append_char_to_stringbuffer('"');
  }

  "\\\\" {
    adjust();
    append_char_to_stringbuffer('\\');
  }

  \\[ \t\n\f]+\\ {
    adjust();
    int i;
    for (i = 0; yytext[i]; i++) {
      if (yytext[i] == '\n') {
        EM_newline();
      }
    }
    continue;
  }

  <<EOF>> {
    EM_error(EM_tokPos, "String not closed at end of file!");
    yyterminate();
  }

  [^\\\n\"]* {
    adjust();
    char *yptr = yytext;
    while (*yptr) {
      append_char_to_stringbuffer(*yptr++);
    }
  }
}


<COMMENT>{
  "/*" {
    adjust();
    commentNesting++;
    continue;
  }

  "*/" {
    adjust();
    commentNesting--;
    if (commentNesting == 0) {
      BEGIN(INITIAL);
    }
  }

  <<EOF>> {
    EM_error(EM_tokPos, "Comment still open at end of file!");
    yyterminate();
  }

  . {
    adjust();
  }
}
