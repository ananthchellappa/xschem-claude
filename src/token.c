/* File: token.c
 *
 * This file is part of XSCHEM,
 * a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
 * simulation.
 * Copyright (C) 1998-2024 Stefan Frederik Schippers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "xschem.h"
#define SPACE(c)  ( c=='\n' || c==' ' || c=='\t' || c=='\0' || c==';' )

enum status {TOK_BEGIN, TOK_TOKEN, TOK_SEP, TOK_VALUE, TOK_END, TOK_ENDTOK};

/* True when `s` holds nothing get_tok_value() would ever read as a value: NULL, empty,
 * or made up entirely of separator characters. It lives here, next to SPACE(), so the
 * two cannot drift apart -- and note SPACE() counts ';' as a separator as well as the
 * obvious whitespace, so `key=;` is every bit as destructive as `key=`.
 *
 * A producer must quote such a value. Unquoted, the state machine below leaves TOK_SEP
 * on every one of those characters and takes the NEXT TOKEN as the value, so `name= `
 * followed by `dir=in` yields name=="dir=in" and no `dir` attribute at all. Measured on
 * space, tab, newline, ';' and mixes of them; only key="" is safe. Issue 0183. */
int str_is_blank(const char *s)
{
  if(!s) return 1;
  while(*s) {
    if(!SPACE(*s)) return 0;
    ++s;
  }
  return 1;
}

unsigned int str_hash(const char *tok)
{
  register unsigned int hash = 5381;
  register unsigned int c;

  while ( (c = (unsigned char)*tok++) ) {
    hash += (hash << 5) + c;
  }
  return hash;
}

static char *find_bracket(char *s)
{
 while(*s!='['&& *s!='\0') s++;
 return s;
}

void floater_hash_all_names(void)
{
  int i;
  int_hash_free(&xctx->floater_inst_table);
  int_hash_init(&xctx->floater_inst_table, HASHSIZE);
  for(i=0; i<xctx->instances; ++i) {
    if(xctx->inst[i].instname && xctx->inst[i].instname[0]) {
      int_hash_lookup(&xctx->floater_inst_table, xctx->inst[i].instname, i, XINSERT);
    }
  }
}

/* if cmd is wrapped inside tcleval(...) pass the content to tcl
 * for evaluation, return tcl result. If no tcleval(...) found return copy of cmd */
const char *tcl_hook2(const char *cmd)
{
  static char *result = NULL;
  static const char *empty="";
  char *unescaped_res;

  if(cmd == NULL) {
    my_free(_ALLOC_ID_, &result);
    return empty;
  }
  if(strstr(cmd, "tcleval(") == cmd) {
    unescaped_res = str_replace(cmd, "\\}", "}", 0, -1);
    tclvareval("tclpropeval2 {", unescaped_res, "}" , NULL);
    my_strdup2(_ALLOC_ID_, &result, tclresult());
    /* dbg(0, "tcl_hook2: return: %s\n", result);*/
  } else {
    /* dbg(0, "tcl_hook2: return: %s\n", cmd); */
    my_strdup2(_ALLOC_ID_, &result, cmd);
  }
  return result;
}

int is_generator(const char *name)
{
  #ifdef __unix__
  int res = 0;
  static regex_t *re = NULL;

  if(!name) {
    if(re) {
      regfree(re);
      my_free(_ALLOC_ID_, &re);
    }
    return 0;
  }
  if(!re) {
    re = my_malloc(_ALLOC_ID_, sizeof(regex_t));
    regcomp(re, "^[^ \t()]+\\([^()]*\\)[ \t]*$", REG_NOSUB | REG_EXTENDED);
  }
  if(!regexec(re, name, 0 , NULL, 0) ) res = 1;
  dbg(1, "is_generator(%s)=%d\n", name, res);
  /* regfree(&re); */
  return res;
  #else
  if (!name) return 0;
  char cmd[PATH_MAX+100];
  my_snprintf(cmd, S(cmd), "regexp {%s} {%s} [list %s]", "-nocase", "^[^ \\t()]+\\([^()]*\\)[ \\t]*$", name);
  tcleval(cmd);
  int ret = atoi(tclresult());
  if (ret > 0)
      return 1;
  return 0;
  #endif
}

/* cleanup syntax of symbol generators: xxx(a,b,c) --> xxx_a_b_c */
const char *sanitize(const char *name)
{
  static char *s = NULL;
  static char *empty="";

  if(!is_generator(name)) {
    my_strdup2(_ALLOC_ID_, &s, name);
    return s;
  }
  if(name == NULL) {
    my_free(_ALLOC_ID_, &s);
    return empty;
  }
  dbg(1, "sanitize(): name=%s\n", name);
  {
    /* the symbol name is DATA -- issue 0817 Z.4. tclresult() may not be handed
     * to tcl_call() directly: tclsetvar() writes through the interpreter and
     * invalidates it, so the first pass is copied out before the second. */
    char pass1[PATH_MAX + 100];
    my_strncpy(pass1, tcl_call("regsub -all { *[.(),] *}", name, NULL, "_"), S(pass1));
    my_strdup2(_ALLOC_ID_, &s, tcl_call("regsub {_$}", pass1, NULL, "{}"));
  }
  dbg(1, "sanitize(): s=%s\n", s);
  return s;
}

/* caller must free returned string
 * given xxxx(a,b,c) return /path/to/xxxx a b c
 * if no xxxx generator file found return NULL */
char *get_generator_command(const char *str)
{
  char *cmd = NULL;
  char *gen_cmd = NULL;
  const char *cmd_filename;
  char *spc_idx;
  struct stat buf;

  dbg(1, "get_generator_command(): symgen=%s\n",str);
  cmd = str_chars_replace(str, " (),", ' '); /* transform str="xxx(a,b,c)" into cmd="xxx a b c" */
  spc_idx = strchr(cmd, ' ');
  if(!spc_idx) {
    goto end;
  }
  *spc_idx = '\0';
  cmd_filename = abs_sym_path(cmd, "");
  if(stat(cmd_filename, &buf)) { /* symbol generator not found */
    goto end;
  }
  #ifdef __unix__
  /* my_strdup(_ALLOC_ID_, &gen_cmd, cmd_filename); */
  /* add quotes to protect spaces in cmd path */
  my_mstrcat(_ALLOC_ID_, &gen_cmd, "\"", cmd_filename, "\"", NULL);
  *spc_idx = ' ';
  my_strcat(_ALLOC_ID_, &gen_cmd, spc_idx);
  #else
  /* tclsh "cmd_filename" a b c */
  /* command tclsh is needed so new TCL windows will NOT open */
  /* quotes are needed for filename if filename has spaces */
  *spc_idx = ' ';
  int len = 8 + strlen(cmd_filename) + strlen(spc_idx) + 1; /*8="tclsh "+ "\""*2*/
  gen_cmd = my_malloc(_ALLOC_ID_, len * sizeof(char));
  my_snprintf(gen_cmd, len, "tclsh \"%s\"%s", cmd_filename, spc_idx);
  #endif
  dbg(1, "get_generator_command(): cmd_filename=%s\n", cmd_filename);
  dbg(1, "get_generator_command(): gen_cmd=%s\n", gen_cmd);
  dbg(1, "get_generator_command(): is_generator=%d\n", is_generator(str));

  end:
  my_free(_ALLOC_ID_, &cmd);
  return gen_cmd;
}

int match_symbol(const char *name)  /* never returns -1, if symbol not found load systemlib/missing.sym */
{
  int i,found;

  found=0;
  dbg(1, "match_symbol(): name=%s\n", name);
  for(i=0;i<xctx->symbols; ++i) {
    /* dbg(1, "match_symbol(): name=%s, sym[i].name=%s\n",name, xctx->sym[i].name);*/
    if(xctx->x_strcmp(name, xctx->sym[i].name) == 0)
    {
      dbg(1, "match_symbol(): found matching symbol:%s\n",name);
      found=1;break;
    }
  }
  if(!found) {
    dbg(1, "match_symbol(): matching symbol not found: loading %s\n", name);
    load_sym_def(name, NULL); /* append another symbol to the xctx->sym[] array */
  }
  dbg(1, "match_symbol(): returning %d\n",i);
  return i;
}

/* update **s modifying only the token values that are */
/* different between *new and *old */
/* return 1 if s modified 20081221 */
int set_different_token(char **s,const char *new, const char *old)
{
 register int c, state=TOK_BEGIN, space;
 char *token=NULL, *value=NULL;
 size_t sizetok=0, sizeval=0;
 size_t token_pos=0, value_pos=0;
 int quote=0;
 int escape=0;
 int mod;
 const char *my_new;

 mod=0;
 my_new = new;
 dbg(1, "set_different_token(): *s=%s, new=%s, old=%s\n",*s, new, old);
 if(new==NULL) return 0;

 sizeval = sizetok = CADCHUNKALLOC;
 my_realloc(_ALLOC_ID_, &token, sizetok);
 my_realloc(_ALLOC_ID_, &value, sizeval);

 /* parse new string and add / change attributes that are missing / different from old */
 while(1) {
  c=*my_new++;
  space=SPACE(c) ;
  if(c=='"' && !escape) quote=!quote;
  if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
  else if( state==TOK_TOKEN && space) state=TOK_ENDTOK;
  else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
  else if( state==TOK_SEP && !space) state=TOK_VALUE;
  else if( state==TOK_VALUE && space && !quote && !escape) state=TOK_END;
  STR_ALLOC(&value, value_pos, &sizeval);
  STR_ALLOC(&token, token_pos, &sizetok);
  if(state==TOK_TOKEN) token[token_pos++]=(char)c;
  else if(state==TOK_VALUE) {
   value[value_pos++]=(char)c;
  }
  else if(state==TOK_ENDTOK || state==TOK_SEP) {
   if(token_pos) {
     token[token_pos]='\0';
     token_pos=0;
   }
  } else if(state==TOK_END) {
   value[value_pos]='\0';
   value_pos=0;
   if(strcmp(value, get_tok_value(old,token,1))) {
    mod=1;
    my_strdup(_ALLOC_ID_, s, subst_token(*s, token, value) );
   }
   state=TOK_BEGIN;
  }
  escape = (c=='\\' && !escape);
  if(c=='\0') break;
 }

 state = TOK_BEGIN;
 escape = quote = 0;
 token_pos = value_pos = 0;
 /* parse old string and remove attributes that are not present in new */
 while(old) {
  c=*old++;
  space=SPACE(c) ;
  if(c=='"' && !escape) quote=!quote;
  if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
  else if( state==TOK_TOKEN && space) state=TOK_ENDTOK;
  else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
  else if( state==TOK_SEP && !space) state=TOK_VALUE;
  else if( state==TOK_VALUE && space && !quote && !escape) state=TOK_END;
  STR_ALLOC(&value, value_pos, &sizeval);
  STR_ALLOC(&token, token_pos, &sizetok);
  if(state==TOK_TOKEN) token[token_pos++]=(char)c;
  else if(state==TOK_VALUE) {
   value[value_pos++]=(char)c;
  }
  else if(state==TOK_ENDTOK || state==TOK_SEP) {
   if(token_pos) {
     token[token_pos]='\0';
     token_pos=0;
   }
   get_tok_value(new,token,1);
   if(xctx->tok_size == 0 ) {
    mod=1;
    my_strdup(_ALLOC_ID_, s, subst_token(*s, token, NULL) );
   }
  } else if(state==TOK_END) {
   value[value_pos]='\0';
   value_pos=0;
   state=TOK_BEGIN;
  }
  escape = (c=='\\' && !escape);
  if(c=='\0') break;
 }
 my_free(_ALLOC_ID_, &token);
 my_free(_ALLOC_ID_, &value);
 return mod;
}

/* return a string containing the list of all tokens in s */
/* with_quotes: */
/* 0: eat non escaped quotes (") */
/* 1: return unescaped quotes as part of the token value if they are present */
/* 2: eat backslashes */
const char *list_tokens(const char *s, int with_quotes)
{
  static char *token=NULL;
  size_t  sizetok=0;
  register int c, state=TOK_BEGIN, space;
  register size_t token_pos=0;
  int quote=0;
  int escape=0;

  if(s==NULL) {
    my_free(_ALLOC_ID_, &token);
    sizetok = 0;
    return "";
  }
  sizetok = CADCHUNKALLOC;
  my_realloc(_ALLOC_ID_, &token, sizetok);
  token[0] = '\0';
  while(1) {
    c=*s++;
    space=SPACE(c) ;
    if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
    else if( state==TOK_TOKEN && space && !quote && !escape) state=TOK_ENDTOK;
    else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
    else if( state==TOK_SEP && !space) state=TOK_VALUE;
    else if( state==TOK_VALUE && space && !quote && !escape ) state=TOK_END;
    STR_ALLOC(&token, token_pos, &sizetok);
    if(c=='"') {
      if(!escape) quote=!quote;
    }
    if(state==TOK_TOKEN) {
      if(c=='"') {
        if((with_quotes & 1) || escape)  token[token_pos++]=(char)c;
      }
      else if( !(c == '\\' && (with_quotes & 2)) ) token[token_pos++]=(char)c;
      else if(escape && c == '\\') token[token_pos++]=(char)c;
    } else if(state==TOK_VALUE) {
      /* do nothing */
    } else if(state==TOK_ENDTOK || state==TOK_SEP) {
        if(token_pos) {
          token[token_pos++]= ' ';
        }
    } else if(state==TOK_END) {
      state=TOK_BEGIN;
    }
    escape = (c=='\\' && !escape);
    if(c=='\0') {
      if(token_pos) {
        token[token_pos-1]= (c != '\0' ) ? ' ' : '\0';
      }
      return token;
    }
  }
}

static int get_sym_pin_number(int sym, const char *pin_name)
{
  int n = -1;
  if(isonlydigit(pin_name)) {
    n = atoi(pin_name);
  }
  else if(pin_name[0]) {
    for(n = 0 ; n < xctx->sym[sym].rects[PINLAYER]; ++n) {
      char *prop = xctx->sym[sym].rect[PINLAYER][n].prop_ptr;
      if(!strcmp(get_tok_value(prop,"name",0), pin_name)) break;
    }
  }
  return n;
}

int get_inst_pin_number(int inst, const char *pin_name)
{
  int n = -1;
  if(isonlydigit(pin_name)) {
    n = atoi(pin_name);
  }
  else if(pin_name[0] && xctx->inst[inst].ptr >= 0) {
    for(n = 0 ; n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]; ++n) {
      char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][n].prop_ptr;
      if(!strcmp(get_tok_value(prop,"name",0), pin_name)) break;
    }
  }
  return n;
}

/* given @#ADD[3:0]:net_name return ADD[3:0] in pin_num_or_name and net_name in pin_attr */
static void get_pin_and_attr(const char *token, char **pin_num_or_name, char **pin_attr)
{
  const char *p = token + 2;
  int bracket = 0, done = 0;
  const char *colon = strchr(token + 2, ':');

  while(colon && *p) {
    if(*p == '[') bracket = 1;
    if(*p == ':' && !bracket) {
      /*   01234567890123456
       *   @#A[3:0]:net_name */
      *pin_num_or_name = my_malloc(_ALLOC_ID_, p - token - 1);
      memcpy(*pin_num_or_name, token + 2, p - token - 2);
      (*pin_num_or_name)[p - token - 2] = '\0';
      my_strdup2(_ALLOC_ID_, pin_attr, p + 1);
      done = 1;
      break;
    }
    if(*p == ']') bracket = 0;
    p++;
  }
  if(!done) {
    my_strdup2(_ALLOC_ID_, pin_num_or_name, token + 2);
    my_strdup2(_ALLOC_ID_, pin_attr, "");
  }
  dbg(1, "get_pin_and_attr(): token=%s, name=%s, attr=%s\n", token,
      *pin_num_or_name ? *pin_num_or_name : "<NULL>",
      *pin_attr ? *pin_attr: "<NULL>");
}

/* state machine that parses a string made up of <token>=<value> ... */
/* couples and returns the value of the given token  */
/* if s==NULL or no match return empty string */
/* NULL tok is used  with NULL s to free internal storage (destructor) */
/* never returns NULL... */
/* with_quotes: */
/* bit 0: */
/* 0: eat unescaped backslashes and unescaped double quotes (") */
/* 1: return backslashes and quotes as part of the token value if they are present */
/* bit 1: */
/* 1: do not perform tcl_hook2 substitution */
/* bit: 2 = 1: same as bit 0 = 1, but remove surrounding "..." quotes, keep everything in between */
/* with_quotes values used in xschem: 0  1  2  4  6 */


const char *get_tok_value(const char *s,const char *tok, int with_quotes)
{
  static char *result=NULL;
  static char *token=NULL;
  static int size=0;
  static int  sizetok=0;
  register int c, space;
  register int token_pos=0, value_pos=0;
  int quote=0, state=TOK_BEGIN;
  int escape=0;
  int cmp = 1;
  static char *translated_tok = NULL;

  xctx->tok_size = 0;

  if(s==NULL) {
    if(tok == NULL) {
      my_free(_ALLOC_ID_, &result);
      my_free(_ALLOC_ID_, &token);
      my_free(_ALLOC_ID_, &translated_tok);
      size = sizetok = 0;
      dbg(2, "get_tok_value(): clear static data\n");
    }
    return "";
  }
  if(!tok || !strstr(s, tok)) return "";
  /* dbg(0, "get_tok_value(): looking for <%s> in <%.30s>\n",tok,s); */
  if( size == 0 ) {
    sizetok = size = CADCHUNKALLOC;
    my_realloc(_ALLOC_ID_, &result, size);
    my_realloc(_ALLOC_ID_, &token, sizetok);
  }
  while(1) {
    c=*s++;
    space=SPACE(c) ;
    if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
    else if( state==TOK_TOKEN && space && !quote && !escape) state=TOK_ENDTOK;
    else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
    else if( state==TOK_SEP && !space) state=TOK_VALUE;
    else if( state==TOK_VALUE && space && !quote && !escape ) state=TOK_END;
    /* don't use STR_ALLOC() for efficiency reasons */
    if(value_pos>=size) {
      size+=CADCHUNKALLOC;
      my_realloc(_ALLOC_ID_, &result,size);
    }
    if(token_pos>=sizetok) {
      sizetok+=CADCHUNKALLOC;
      my_realloc(_ALLOC_ID_, &token,sizetok);
    }
    if(c=='"') {
      if(!escape) quote=!quote;
    }
    if(state==TOK_TOKEN) {
      if(!cmp) { /* previous token matched search and was without value, return xctx->tok_size */
        result[0] = '\0';
        return result;
      }
      /* if( (with_quotes & 1) || escape || (c != '\\' && c != '"')) token[token_pos++]=(char)c; */
      token[token_pos++]=(char)c;

    } else if(state == TOK_VALUE) {
      if( with_quotes & 1) result[value_pos++] = (char)c;
      else if(( with_quotes & 4) && (escape || c != '"')) result[value_pos++] = (char)c;
      else if( escape || (c != '\\' && c != '"')) result[value_pos++]=(char)c;
    } else if(state == TOK_ENDTOK || state == TOK_SEP) {
        if(token_pos) {
          token[token_pos] = '\0';
          if( !(cmp = strcmp(token,tok)) ) {
            /* report back also token size, useful to check if requested token exists */
            xctx->tok_size = token_pos;
          }
          /* dbg(2, "get_tok_value(): token=%s\n", token);*/
          token_pos=0;
        }
    } else if(state==TOK_END) {
      result[value_pos]='\0';
      if( !cmp ) {
        if(with_quotes & 2) {
          return result;
        } else {
          my_strdup2(_ALLOC_ID_, &translated_tok, tcl_hook2(result));
          return translated_tok;
        }
      }
      value_pos=0;
      state=TOK_BEGIN;
    }
    escape = (c=='\\' && !escape);
    if(c=='\0') {
      result[0]='\0';
      xctx->tok_size = 0;
      return result;
    }
  }
}

/* return template string excluding name=... and token=value where token listed in extra */
/* drop spiceprefix attribute */
const char *get_sym_template(char *s,char *extra)
{
 static char *result=NULL;
 size_t sizeres=0;
 size_t sizetok=0;
 size_t sizeval=0;
 char *value=NULL;
 char *token=NULL;
 register int c, state=TOK_BEGIN, space;
 register size_t token_pos=0, value_pos=0, result_pos=0;
 int quote=0;
 int escape=0;
 int with_quotes=0;
 size_t l;
/* with_quotes: */
/* 0: eat non escaped quotes (") */
/* 1: return unescaped quotes as part of the token value if they are present */
/* 2: eat backslashes */
/* 3: 1+2  :) */

 dbg(1, "get_sym_template(): s=%s, extra=%s\n", s ? s : "<NULL>", extra ? extra : "<NULL>");
 if(s==NULL) {
   my_free(_ALLOC_ID_, &result);
   return "";
 }
 l = strlen(s);
 STR_ALLOC(&result, l+1, &sizeres);
 result[0] = '\0';
 sizetok = sizeval = CADCHUNKALLOC;
 my_realloc(_ALLOC_ID_, &value,sizeval);
 my_realloc(_ALLOC_ID_, &token,sizetok);
 while(1) {
  c=*s++;
  space=SPACE(c) ;
  dbg(1, "state=%d", state);
  if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
  else if( state==TOK_TOKEN && space) state=TOK_ENDTOK;
  else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
  else if( state==TOK_SEP && !space) state=TOK_VALUE;
  else if( state==TOK_VALUE && space && !quote) state=TOK_END;
  dbg(1, " --> state=%d\n", state);
  STR_ALLOC(&value, value_pos, &sizeval);
  STR_ALLOC(&token, token_pos, &sizetok);
  if(c=='"') {
    if(!escape) quote=!quote;
  }
  if(state==TOK_BEGIN) {
    result[result_pos++] = (char)c;
  } else if(state==TOK_TOKEN) {
    /* token[token_pos++]=(char)c; */
    if( (with_quotes & 1) || escape || (c != '\\' && c != '"')) token[token_pos++]=(char)c;
  } else if(state==TOK_VALUE) {
    /* if((with_quotes & 1) || escape)  value[value_pos++]=(char)c; */
    if( (with_quotes & 1) || escape || (c != '\\' && c != '"')) value[value_pos++]=(char)c;
  } else if(state==TOK_END) {
    value[value_pos]='\0';
    if((!extra || !strstr(extra, token)) && strcmp(token,"name") &&
      strcmp(token,"spiceprefix") && strcmp(token,"model")) {
      memcpy(result+result_pos, value, value_pos+1);
      result_pos+=value_pos;
    }
    result[result_pos++] = (char)c;
    value_pos=0;
    token_pos=0;
    state=TOK_BEGIN;
  } else if(state==TOK_ENDTOK || state==TOK_SEP) {
    if(token_pos) {
      token[token_pos]='\0';
      dbg(1, "token=|%s|\n", token);
      if((!extra || !strstr(extra, token)) && strcmp(token,"name") &&
        strcmp(token,"spiceprefix") && strcmp(token,"model")) {
        memcpy(result+result_pos, token, token_pos+1);
        result_pos+=token_pos;
        result[result_pos++] = (char)c;
      }
      token_pos=0;
    }
  }
  escape = (c=='\\' && !escape);
  if(c=='\0') {
    if(result_pos && result[result_pos - 1 ] != '\0') result[result_pos++] = '\0';
    break;
  }
 }
 my_free(_ALLOC_ID_, &value);
 my_free(_ALLOC_ID_, &token);
 dbg(1, "get_sym_template(): result=|%s|\n", result);
 return result;
}

/* caller is responsible for freeing up storage for return value
 * return NULL if no matching token found
 * caller is responsible for freeing up storage for pin_attr_value */
static char *get_pin_attr_from_inst(int inst, int pin, const char *attr)
{
   size_t attr_size;
   char *pinname = NULL, *pname = NULL, *pin_attr_value = NULL;
   char *pnumber = NULL;
   const char *str;


   dbg(1, "get_pin_attr_from_inst(): inst=%d pin=%d attr=%s\n", inst, pin, attr);
   if(xctx->inst[inst].ptr < 0 ) return NULL;
   pin_attr_value = NULL;
   str = get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][pin].prop_ptr,"name",0);
   if(str[0]) {
     size_t tok_val_len;
     tok_val_len = strlen(str);
     attr_size = strlen(attr);
     my_strdup(_ALLOC_ID_, &pinname, str);
     pname =my_malloc(_ALLOC_ID_, tok_val_len + attr_size + 30);
     my_snprintf(pname, tok_val_len + attr_size + 30, "%s(%s)", attr, pinname);
     my_free(_ALLOC_ID_, &pinname);
     str = get_tok_value(xctx->inst[inst].prop_ptr, pname, 0);
     my_free(_ALLOC_ID_, &pname);
     if(xctx->tok_size) my_strdup2(_ALLOC_ID_, &pin_attr_value, str);
     else {
       pnumber = my_malloc(_ALLOC_ID_, attr_size + 100);
       my_snprintf(pnumber, attr_size + 100, "%s(%d)", attr, pin);
       str = get_tok_value(xctx->inst[inst].prop_ptr, pnumber, 0);
       dbg(1, "get_pin_attr_from_inst(): pnumber=%s\n", pnumber);
       my_free(_ALLOC_ID_, &pnumber);
       if(xctx->tok_size) my_strdup2(_ALLOC_ID_, &pin_attr_value, str);
     }
   }
   return pin_attr_value;
}

int get_last_used_index(const char *old_basename, const char *brkt)
{
  int retval = 1;
  Int_hashentry *entry;
  size_t size = strlen(old_basename) + strlen(brkt)+40;
  char *refname = my_malloc(_ALLOC_ID_, size);
  my_snprintf(refname, size, "_@%s@%s", old_basename, brkt);
  entry = int_hash_lookup(&xctx->inst_name_table, refname, 0, XLOOKUP);
  if(entry) retval = entry->value;
  my_free(_ALLOC_ID_, &refname);
  return retval;
}

/* if inst == -1 hash all instance names, else do only given instance
 * action can be XINSERT or XDELETE to insert or remove items */
void hash_names(int inst, int action)
{
  int i, xmult, start, stop;
  char *upinst = NULL;
  char *upinst_ptr, *upinst_state, *single_name;
  dbg(1, "hash_names(): inst=%d, action=%d\n", inst, action);
  if(inst == -1) {
    int_hash_free(&xctx->inst_name_table);
    int_hash_init(&xctx->inst_name_table, HASHSIZE);
  }
  if(inst == -1) {
     start = 0;
     stop =  xctx->instances;
  } else {
    start = inst;
    stop = inst + 1;
  }
  if(inst != -1) dbg(1, "hash_names(): start=%d, stop=%d, instname=%s\n",
        start, stop, xctx->inst[inst].instname? xctx->inst[inst].instname : "<NULL>");
  for(i = start; i < stop; ++i) {
    if(xctx->inst[i].instname && xctx->inst[i].instname[0]) {
      my_strdup(_ALLOC_ID_, &upinst, expandlabel(xctx->inst[i].instname, &xmult));
      strtoupper(upinst);

      upinst_ptr = upinst;
      while( (single_name = my_strtok_r(upinst_ptr, ",", "", 0, &upinst_state)) ) {
        upinst_ptr = NULL;
        dbg(1, "hash_names(): inst %d, name %s --> %d\n", i, single_name, action);
        int_hash_lookup(&xctx->inst_name_table, single_name, i, action);
        dbg(1, "hash_names(): hashing %s from %s\n", single_name, xctx->inst[i].instname);
      }
    }
  }
  if(upinst) my_free(_ALLOC_ID_, &upinst);
}

/* return -1 if name is not used, else return first instance number with same name found
 * old_basename: base name (without [...]) of instance name the new 'name' was built from
 * brkt: pointer to '[...]' part of instance name (or empty string if no [...] found)
 * q: integer number added to 'name' when trying an unused instance name
 *    (name = old_basename + q + bracket)
 *    or -1 if only testing for unique 'name'.
 */

static int name_is_used(char *name, const char *old_basename, const char *brkt, int q)
{
  int xmult, used = -1;
  char *upinst = NULL;
  char *upinst_ptr, *upinst_state, *single_name;
  Int_hashentry *entry;
  my_strdup(_ALLOC_ID_, &upinst, expandlabel(name, &xmult));
  strtoupper(upinst);
  upinst_ptr = upinst;
  while( (single_name = my_strtok_r(upinst_ptr, ",", "", 0, &upinst_state)) ) {
    upinst_ptr = NULL;
    entry = int_hash_lookup(&xctx->inst_name_table, single_name, 1, XLOOKUP);
    if(entry) {
      used = entry->value;
      break;
    }
  }
  my_free(_ALLOC_ID_, &upinst);
  dbg(1, "name_is_used(%s): return inst %d\n", name, used);

  if(q != -1 && used == -1) {
    size_t size = strlen(old_basename) + strlen(brkt)+40;
    char *refname = my_malloc(_ALLOC_ID_, size);
    my_snprintf(refname, size, "_@%s@%s", old_basename, brkt);
    int_hash_lookup(&xctx->inst_name_table, refname, q, XINSERT);
    my_free(_ALLOC_ID_, &refname);
  }
  return used;
}

/* given a old_prop property string, return a new
 * property string in xctx->inst[i].prop_ptr such that the element name is
 * unique in current design (that is, element name is changed
 * if necessary)
 * if old_prop=NULL return NULL
 * if old_prop does not contain a valid "name" or empty return old_prop
 * hash_names(-1, XINSERT) must be called before using this function */
void new_prop_string(int i, const char *old_prop, int dis_uniq_names)
{
  char *old_name=NULL, *new_name=NULL;
  const char *brkt;
  const char *new_prop;
  size_t old_name_len;
  int n, q, qq;
  char *old_name_base = NULL;
  char *up_new_name = NULL;
  int is_used;

  dbg(1, "new_prop_string(): i=%d, old_prop=%s\n", i, old_prop);
  if(old_prop==NULL) {
   my_free(_ALLOC_ID_, &xctx->inst[i].prop_ptr);
   return;
  }
  old_name_len = my_strdup(_ALLOC_ID_, &old_name,get_tok_value(old_prop,"name",0) ); /* added old_name_len */

  if(old_name==NULL) {
   my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, old_prop);  /* changed to copy old props if no name */
   my_strdup2(_ALLOC_ID_, &xctx->inst[i].instname, "");
   return;
  }
  /* don't change old_prop if name does not conflict. */
  /* if no hash_names() is done and inst_table uninitialized --> use old_prop */
  is_used =  name_is_used(old_name, "", "", -1);
  if(dis_uniq_names || is_used == -1 || is_used == i) {
   my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, old_prop);
   my_strdup2(_ALLOC_ID_, &xctx->inst[i].instname, old_name);
   my_free(_ALLOC_ID_, &old_name);
   return;
  }
  /* old_name is not unique. Find another unique name */
  old_name_base = my_malloc(_ALLOC_ID_, old_name_len+1);
  n = sscanf(old_name, "%[^[0-9]",old_name_base);
  if(!n) old_name_base[0] = '\0'; /* there is no basename (like in "[3:0]" or "12"), set to empty string */
  brkt=find_bracket(old_name); /* if no bracket found will point to end of string ('\0') */
  my_realloc(_ALLOC_ID_, &new_name, old_name_len + 40);


  qq = get_last_used_index(old_name_base, brkt); /*  */
  for(q = qq;; ++q) {
    my_snprintf(new_name, old_name_len + 40, "%s%d%s", old_name_base, q, brkt);
    is_used = name_is_used(new_name, old_name_base, brkt, q);
    if(is_used == -1 ) break;
  }
  my_free(_ALLOC_ID_, &old_name_base);
  dbg(1, "new_prop_string(): new_name=%s\n", new_name);
  new_prop = subst_token(old_prop, "name", new_name);
  dbg(1, "new_prop_string(): old_prop=|%s|\n", old_prop);
  dbg(1, "new_prop_string(): new_prop=|%s|\n", new_prop);
  if(strcmp(new_prop, old_prop) ) {
    my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, new_prop);
    my_strdup2(_ALLOC_ID_, &xctx->inst[i].instname, new_name);
  }
  my_free(_ALLOC_ID_, &old_name);
  my_free(_ALLOC_ID_, &new_name);
  my_free(_ALLOC_ID_, &up_new_name);
}

void check_unique_names(int rename)
{
  int i, first = 1, modified = 0;
  int newpropcnt = 0;
  char *tmp = NULL;
  int used;

  if(xctx->hilight_nets) {
    xctx->enable_drill=0;
    clear_all_hilights();
    draw();
  }
  int_hash_free(&xctx->inst_name_table);
  int_hash_init(&xctx->inst_name_table, HASHSIZE);

  /* look for duplicates */
  first = 1;
  for(i=0;i<xctx->instances; ++i) {
    if(xctx->inst[i].instname && xctx->inst[i].instname[0]) {
      if(xctx->inst[i].ptr == -1) continue;
      if(!(xctx->inst[i].ptr+ xctx->sym)->type) continue;
      used = name_is_used(xctx->inst[i].instname,"", "", -1);
      hash_names(i, XINSERT_NOREPLACE);
      if( used != -1 && used != i) {
        dbg(0, "check_unique_names(): found duplicate: i=%d name=%s\n", i, xctx->inst[i].instname);
        xctx->inst[i].color = -PINLAYER;
        inst_hilight_hash_lookup(i, -PINLAYER, XINSERT_NOREPLACE);
        if(rename == 1) {
          if(first) {
            bbox(START,0.0,0.0,0.0,0.0);
            modified = 1;
            xctx->push_undo();
            xctx->prep_hash_inst=0;
            xctx->prep_net_structs=0;
            xctx->prep_hi_structs=0;
            first = 0;
          }
          bbox(ADD, xctx->inst[i].x1, xctx->inst[i].y1, xctx->inst[i].x2, xctx->inst[i].y2);
        }
      }
    }
  } /* for(i...) */

  /* rename duplicates */
  if(rename) for(i=0;i<xctx->instances; ++i) {
    if( (xctx->inst[i].color != -10000)) {
      my_strdup(_ALLOC_ID_, &tmp, xctx->inst[i].prop_ptr);
      newpropcnt++;
      new_prop_string(i, tmp, 0);
      hash_names(i, XINSERT);
      symbol_bbox(i, &xctx->inst[i].x1, &xctx->inst[i].y1, &xctx->inst[i].x2, &xctx->inst[i].y2);
      bbox(ADD, xctx->inst[i].x1, xctx->inst[i].y1, xctx->inst[i].x2, xctx->inst[i].y2);
      my_free(_ALLOC_ID_, &tmp);
    }
  } /* for(i...) */
  if(modified) set_modify(1);
  if(rename == 1 && xctx->hilight_nets) {
    bbox(SET,0.0,0.0,0.0,0.0);
    draw();
    bbox(END,0.0,0.0,0.0,0.0);
  }
  redraw_hilights(0);
  int_hash_free(&xctx->inst_name_table);
}

static int is_quoted(const char *s)
{
  size_t len = strlen(s);

  if(s[0] == '"' && s[len - 1] == '"') return 1;
  return 0;
}

int xis_quoted(const char *s)
{
  int c, escape = 0;
  int openquote = 0;
  int closequote = 0;

  while( (c = *s++) ) {
    escape = 0;
    if(c == '\\' && !escape) {
      escape = 1;
      c = *s++;
    }
    if(c == '"' && !escape && !openquote ) {
      openquote = 1;
    }
    else if(c == '"' && !escape && openquote && !closequote) {
      closequote = 1;
    }
    else if(c == '"' && !escape ) {
      return 0;
    }
    else if(!isspace(c) && !openquote) {
      return 0;
    }
    else if(!isspace(c) && openquote && closequote) {
      return 0;
    }
  }
  if(openquote && closequote) return 1;
  return 0;
}


char *is_expr(const char *str)
{
  char *ret = NULL;
  if(str) {
    ret = strstr(str, "expr(");
    if(!ret) ret = strstr(str, "expr_eng(");
    if(!ret) ret = strstr(str, "expr_eng4(");
  }
  return ret;
}

static void print_vhdl_primitive(FILE *fd, int inst) /* netlist  primitives, 20071217 */
{
 int i=0, multip, tmp;
 const char *str_ptr;
 register int c, state=TOK_BEGIN, space;
 const char *lab;
 char *template=NULL,*format=NULL,*s, *name=NULL, *token=NULL;
 const char *value;
 size_t sizetok=0;
 size_t token_pos=0;
 int escape=0;
 int no_of_pins=0;
 char *fmt_attr = NULL;
 char *result = NULL;

 my_strdup(_ALLOC_ID_, &template, (xctx->inst[inst].ptr + xctx->sym)->templ);
 my_strdup(_ALLOC_ID_, &name, xctx->inst[inst].instname);
 fmt_attr = xctx->format ? xctx->format : "vhdl_format";
 if(!name) my_strdup(_ALLOC_ID_, &name, get_tok_value(template, "name", 0));
 /* allow format string override in instance */
 my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr, fmt_attr, 2));
 /* get netlist format rule from symbol */
 if(!xctx->tok_size)
   my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, fmt_attr, 2));
 /* allow format string override in instance */
 if(xctx->tok_size && strcmp(fmt_attr, "vhdl_format"))
    my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr, "vhdl_format", 2));
 /* get netlist format rule from symbol */
 if(!xctx->tok_size && strcmp(fmt_attr, "vhdl_format"))
   my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "vhdl_format", 2));
 if((name==NULL) || (format==NULL) ) {
   my_free(_ALLOC_ID_, &template);
   my_free(_ALLOC_ID_, &name);
   my_free(_ALLOC_ID_, &format);
   return; /*do no netlist unwanted insts(no format) */
 }
 no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
 s=format;
 dbg(1, "print_vhdl_primitive(): name=%s, format=%s xctx->netlist_count=%d\n",name,format, xctx->netlist_count);

 fprintf(fd, "---- start primitive ");
 lab=expandlabel(name, &tmp);
 fprintf(fd, "%d\n",tmp);
 /* begin parsing format string */
 while(1)
 {
  c=*s++;
  if(c=='\\') {
    escape=1;
    c=*s++;
  }
  else escape=0;
  if(c=='\n' && escape ) c=*s++; /* 20171030 eat escaped newlines */
  space=SPACE(c);

  if( state==TOK_BEGIN && (c=='@' || c=='%') && !escape ) state=TOK_TOKEN;
  else if(state==TOK_TOKEN && token_pos > 1 &&
     (
       ( (space  || c == '%' || c == '@') && !escape ) ||
       ( (!space && c != '%' && c != '@') && escape  )
     )
    ) {
    state=TOK_SEP;
  }

  STR_ALLOC(&token, token_pos, &sizetok);
  if(state==TOK_TOKEN) {
    token[token_pos++]=(char)c; /* 20171029 remove escaping backslashes */
  }
  else if(state==TOK_SEP)                    /* got a token */
  {
   token[token_pos]='\0';
   token_pos=0;

   value = get_tok_value(xctx->inst[inst].prop_ptr, token+1, 0);
   /* xctx->tok_size==0 indicates that token(+1) does not exist in instance attributes */
   if(!xctx->tok_size)
   value=get_tok_value(template, token+1, 0);
   if(!xctx->tok_size && token[0] =='%') {
     my_mstrcat(_ALLOC_ID_, &result, token + 1, NULL);
   } else if(value && value[0]!='\0')
   {  /* instance names (name) and node labels (lab) go thru the expandlabel function. */
      /*if something else must be parsed, put an if here! */

    if(!(strcmp(token+1,"name"))) {
      if( (lab=expandlabel(value, &tmp)) != NULL)
         my_mstrcat(_ALLOC_ID_, &result, "----name(", lab, ")", NULL);
      else
         my_mstrcat(_ALLOC_ID_, &result, value, NULL);
    }
    else if(!(strcmp(token+1,"lab"))) {
      if( (lab=expandlabel(value, &tmp)) != NULL)
         my_mstrcat(_ALLOC_ID_, &result, "----pin(", lab, ")", NULL);
      else
         my_mstrcat(_ALLOC_ID_, &result, value, NULL);
    }
    else my_mstrcat(_ALLOC_ID_, &result, value, NULL);
   }
   else if(strcmp(token,"@symref")==0)
   {
     const char *s = get_sym_name(inst, 9999, 1, 0);
     my_mstrcat(_ALLOC_ID_, &result, s, NULL);
   }
   else if(strcmp(token,"@symname")==0) /* of course symname must not be present  */
                                        /* in hash table */
   {
     const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 0, 0)));
     my_mstrcat(_ALLOC_ID_, &result, s, NULL);
   }
   else if (strcmp(token,"@symname_ext")==0)
   {
     const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 1, 0)));
     my_mstrcat(_ALLOC_ID_, &result, s, NULL);
   }
   else if(strcmp(token,"@schname_ext")==0) /* of course schname must not be present  */
                                        /* in hash table */
   {
     my_mstrcat(_ALLOC_ID_, &result, xctx->current_name, NULL);
   }
   else if(strcmp(token,"@schname")==0)
   {
     my_mstrcat(_ALLOC_ID_, &result, get_cell(xctx->current_name, 0), NULL);
   }
   else if(strcmp(token,"@topschname")==0) /* of course topschname must not be present in attributes */
   {
     const char *topsch;
     topsch = get_trailing_path(xctx->sch[0], 0, 1);
     my_mstrcat(_ALLOC_ID_, &result, topsch, NULL);
   }
   else if(strcmp(token,"@pinlist")==0) /* of course pinlist must not be present  */
                                        /* in hash table. print multiplicity */
   {                                    /* and node number: m1 n1 m2 n2 .... */
    Int_hashtable table = {NULL, 0};
    int first = 1;
    int_hash_init(&table, 37);
    for(i=0;i<no_of_pins; ++i)
    {
      char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][i].prop_ptr;
      if(strboolcmp(get_tok_value(prop,"vhdl_ignore",0), "true")) {
        const char *name = get_tok_value(prop,"name",0);
        if(!int_hash_lookup(&table, name, 1, XINSERT_NOREPLACE)) {
          if(!first) my_mstrcat(_ALLOC_ID_, &result, " , ", NULL);
          str_ptr =  net_name(inst,i, &multip, 0, 1);
          my_mstrcat(_ALLOC_ID_, &result, "----pin(", str_ptr, ") ", NULL);
          first = 0;
        }
      }
    }
    int_hash_free(&table);
   }
   else if(token[0]=='@' && token[1]=='@') {    /* recognize single pins 15112003 */
    for(i=0;i<no_of_pins; ++i) {
     xSymbol *ptr = xctx->inst[inst].ptr + xctx->sym;
     if(!strcmp( get_tok_value(ptr->rect[PINLAYER][i].prop_ptr,"name",0), token+2)) {
       if(strboolcmp(get_tok_value(ptr->rect[PINLAYER][i].prop_ptr,"vhdl_ignore",0), "true")) {
         str_ptr =  net_name(inst,i, &multip, 0, 1);
         my_mstrcat(_ALLOC_ID_, &result, "----pin(", str_ptr, ") ", NULL);
       }
       break;
     }
    }
   }

   /* reference by pin number instead of pin name, allows faster lookup of the attached net name
    * @#0, @#1:net_name, @#2:name, ... */
   else if(token[0]=='@' && token[1]=='#') {
     int n;
     char *pin_attr = NULL;
     char *pin_num_or_name = NULL;

     get_pin_and_attr(token, &pin_num_or_name, &pin_attr);
     n = get_inst_pin_number(inst, pin_num_or_name);
     if(n>=0  && pin_attr[0] && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
       char *pin_attr_value = NULL;
       int is_net_name = !strcmp(pin_attr, "net_name");
       /* get pin_attr value from instance: "pinnumber(ENABLE)=5" --> return 5, attr "pinnumber" of pin "ENABLE"
        *                                   "pinnumber(3)=6       --> return 6, attr "pinnumber" of 4th pin */
       if(!is_net_name) {
         pin_attr_value = get_pin_attr_from_inst(inst, n, pin_attr);
         /* get pin_attr from instance pin attribute string */
         if(!pin_attr_value) {
          my_strdup(_ALLOC_ID_, &pin_attr_value,
             get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][n].prop_ptr, pin_attr, 0));
         }
       }
       /* @#n:net_name attribute (n = pin number or name) will translate to net name attached  to pin */
       if(!pin_attr_value && is_net_name) {
         prepare_netlist_structs(0);
         my_strdup(_ALLOC_ID_, &pin_attr_value,
              xctx->inst[inst].node && xctx->inst[inst].node[n] ? xctx->inst[inst].node[n] : "?");
       }
       if(!pin_attr_value ) my_strdup(_ALLOC_ID_, &pin_attr_value, "--UNDEF--");
       value = pin_attr_value;
       /* recognize slotted devices: instname = "U3:3", value = "a:b:c:d" --> value = "c" */
       if(value[0] && !strcmp(pin_attr, "pinnumber") ) {
         char *ss;
         int slot;
         char *tmpstr = NULL;
         tmpstr = my_malloc(_ALLOC_ID_, sizeof(xctx->inst[inst].instname));
         if( (ss=strchr(xctx->inst[inst].instname, ':')) ) {
           sscanf(ss+1, "%s", tmpstr);
           if(isonlydigit(tmpstr)) {
             slot = atoi(tmpstr);
             if(strstr(value,":")) value = find_nth(value, ":", "", 0, slot);
           }
         }
         my_free(_ALLOC_ID_, &tmpstr);
       }
       my_mstrcat(_ALLOC_ID_, &result, value, NULL);
       my_free(_ALLOC_ID_, &pin_attr_value);
     }
     else if(n>=0  && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
       const char *si;
       char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][n].prop_ptr;
       si  = get_tok_value(prop, "verilog_ignore",0);
       if(strboolcmp(si, "true")) {
         str_ptr =  net_name(inst,n, &multip, 0, 1);
         my_mstrcat(_ALLOC_ID_, &result, "----pin(", str_ptr, ") ", NULL);
       }
     }
     my_free(_ALLOC_ID_, &pin_attr);
     my_free(_ALLOC_ID_, &pin_num_or_name);
   }

   else if(!strncmp(token,"@tcleval", 8)) {
     /* char tclcmd[strlen(token)+100] ; */
     size_t s;
     char *tclcmd=NULL;
     s = token_pos + strlen(name) + strlen(xctx->inst[inst].name) + 100;
     tclcmd = my_malloc(_ALLOC_ID_, s);
     Tcl_ResetResult(interp);
     my_snprintf(tclcmd, s, "tclpropeval {%s} {%s} {%s}", token, name, xctx->inst[inst].name);
     tcleval(tclcmd);
     my_mstrcat(_ALLOC_ID_, &result, tclresult(), NULL);
     my_free(_ALLOC_ID_, &tclcmd);
   }

   if(c!='%' && c!='@' && c!='\0' ) {
     char str[2];
     str[0] = (unsigned char) c;
     str[1] = (unsigned char)'\0';
     my_mstrcat(_ALLOC_ID_, &result, str, NULL);
   }
   if(c == '@' || c == '%') s--;
   state=TOK_BEGIN;
  }
  else if(state==TOK_BEGIN && c!='\0') {
    char str[2];
    str[0] = (unsigned char) c;
    str[1] = (unsigned char)'\0';
    my_mstrcat(_ALLOC_ID_, &result, str, NULL);
  }

  if(c=='\0')
  {
    char *parent_prop_ptr = NULL;

    if(xctx->currsch > 0) {
      parent_prop_ptr = xctx->hier_attr[xctx->currsch - 1].prop_ptr;
    }
    /* if result is like: 'tcleval(some_string)' pass it thru tcl evaluation so expressions
     * can be calculated. Before that do also a round of translation to remove remaining @params */
    if(result) {
      dbg(1, "print_vhdl_primitive(): before translate3() result=%s\n", result);
      if(strchr(result, '@')) {
        /* netlist_commands often have @ characters due to ngspice syntax. Do not translate */
        if(strcmp(xctx->sym[xctx->inst[inst].ptr].type, "netlist_commands")) {
          my_strdup2(_ALLOC_ID_, &result,
            translate3(result, 0, xctx->inst[inst].prop_ptr, parent_prop_ptr, NULL, NULL));
          /* can not put template in above translate3: -----------------------^^^^
           * if instance has VHI=VHI, format string has VHI=@VHI, and symbol template has VHI=3
           * we do not want token @VHI to resolve to 3, but stop at VHI as specified in instance */
          if(strchr(result, '@')) {
             my_strdup2(_ALLOC_ID_, &result,
                translate3(result, 0, xctx->inst[inst].prop_ptr, parent_prop_ptr, template, NULL));
          }
        }
      }
      my_strdup2(_ALLOC_ID_, &result, tcl_hook2(result)); /* tcl evaluation if tcleval(....) */
      if(is_expr(result)) {
        my_strdup2(_ALLOC_ID_, &result, eval_expr(result));
      }
      dbg(1, "print_vhdl_primitive(): after  translate3() result=%s\n", result);
    }
    if(result) fprintf(fd, "%s", result);
    fputc('\n',fd);
    fprintf(fd, "---- end primitive\n");
    break ;
  }
 } /* while(1) */
 my_free(_ALLOC_ID_, &result);
 my_free(_ALLOC_ID_, &template);
 my_free(_ALLOC_ID_, &format);
 my_free(_ALLOC_ID_, &name);
 my_free(_ALLOC_ID_, &token);
}

const char *subst_token(const char *s, const char *tok, const char *new_val)
/* given a string <s> with multiple "token=value ..." assignments */
/* substitute <tok>'s value with <new_val> */
/* if tok not found in s and new_val!=NULL add tok=new_val at end.*/
/* if new_val is NULL *OR* empty *remove* 'token (and =val if any)' from s */
/* return the updated string */
{
  static char *result=NULL;
  size_t size=0;
  register int c, state=TOK_BEGIN, space;
  size_t sizetok=0;
  char *token=NULL;
  size_t token_pos=0, result_pos=0, result_save_pos = 0, tmp;
  int quote=0;
  int done_subst=0;
  int escape=0, matched_tok=0, removed_tok = 0;
  char *new_val_copy = NULL;
  size_t new_val_len;

  if(s==NULL && tok == NULL){
    my_free(_ALLOC_ID_, &result);
    return "";
  }
  if((tok == NULL || tok[0]=='\0') && s ){
    my_strdup2(_ALLOC_ID_, &result, s);
    return result;
  }
  if( (!s || s[0] == '\0') && tok && new_val) {
    my_strdup2(_ALLOC_ID_, &result, tok);
    my_mstrcat(_ALLOC_ID_, &result, "=", new_val, NULL);
    return result;
  }
  /* quote new_val if it contains newlines and not "name" token */
  if(new_val) {
    new_val_len = strlen(new_val);
    if(strcmp(tok, "name") && !is_quoted(new_val) && strpbrk(new_val, ";\n \t")) {
      new_val_copy = my_malloc(_ALLOC_ID_, new_val_len+3);
      my_snprintf(new_val_copy, new_val_len+3, "\"%s\"", new_val);
    }
    else my_strdup(_ALLOC_ID_, &new_val_copy, new_val); /* new_val_copy is NULL if new_val empty */
  } else new_val_copy = NULL;

  /* if new_val is NULL or empty new_val_copy will be NULL */

  dbg(1, "subst_token(): %s, %s, %s\n", s ? s : "<NULL>", tok ? tok : "<NULL>", new_val ? new_val : "<NULL>");
  sizetok = size = CADCHUNKALLOC;
  my_realloc(_ALLOC_ID_, &result, size);
  my_realloc(_ALLOC_ID_, &token, sizetok);
  result[0] = '\0';
  while( s ) {
    c=*s++;
    space=SPACE(c);
    if(c == '"' && !escape) quote=!quote;
    /* alloc data */
    STR_ALLOC(&result, result_pos, &size);
    STR_ALLOC(&token, token_pos, &sizetok);

    /* parsing state machine                                    */
    /* states:                                                  */
    /*    TOK_BEGIN TOK_TOKEN TOK_ENDTOK TOK_SEP TOK_VALUE      */
    /*                                                          */
    /*                                                          */
    /* TOK_BEGIN                                                */
    /* |      TOK_TOKEN                                         */
    /* |      |   TOK_ENDTOK                                    */
    /* |      |   |  TOK_SEP                                    */
    /* |      |   |  | TOK_VALUE                                */
    /* |      |   |  | | TOK_BEGIN                              */
    /* |      |   |  | | |   TOK_TOKEN                          */
    /* |      |   |  | | |   |     TOK_ENDTOK                   */
    /* |      |   |  | | |   |     |  TOK_TOKEN                 */
    /* |      |   |  | | |   |     |  |                         */
    /* .......name...=.x1....format...type..=..subcircuit....   */
    /* . : space                                                */

    if(state == TOK_BEGIN && !space && c != '=' ) {
      result_save_pos = result_pos;
      token_pos = 0;
      state = TOK_TOKEN;
    } else if(state == TOK_ENDTOK  && (!space || c == '\0') && c != '=' ) {
      if(!done_subst && matched_tok) {
        if(new_val_copy) { /* add new_val_copy to matching token with no value */
          if(new_val_copy[0]) {
            tmp = strlen(new_val_copy);
          } else {
            new_val_copy = "\"\"";
            tmp = 2;
          }

          STR_ALLOC(&result, tmp+2 + result_pos, &size);
          memcpy(result + result_pos, "=", 1);
          memcpy(result + result_pos+1, new_val_copy, tmp);
          memcpy(result + result_pos+1+tmp, " ", 1);
          result_pos += tmp + 2;
          done_subst = 1;
        } else { /* remove token (and value if any) */
          result_pos = result_save_pos;
          done_subst = 1;
          removed_tok = 1;
        }
      }
      result_save_pos = result_pos;
      if(c != '\0') state = TOK_TOKEN; /* if end of string remain in TOK_ENDTOK state */
    } else if( state == TOK_TOKEN && space) {
      token[token_pos] = '\0';
      token_pos = 0;
      matched_tok = !strcmp(token, tok) && !done_subst;
      state=TOK_ENDTOK;
      if(c == '\0') {
        s--; /* go to next iteration and process '\0' as TOK_ENDTOK */
        continue;
      }
    } else if(state == TOK_TOKEN && c=='=') {
      token[token_pos] = '\0';
      token_pos = 0;
      matched_tok = !strcmp(token, tok) && !done_subst;
      state=TOK_SEP;
    } else if(state == TOK_ENDTOK && c=='=') {
      state=TOK_SEP;
    } else if( state == TOK_SEP && !space) {
      if(!done_subst && matched_tok) {
        if(new_val_copy) { /* replace token value with new_val_copy */
          if(new_val_copy[0]) {
            tmp = strlen(new_val_copy);
          } else {
            new_val_copy = "\"\"";
            tmp = 2;
          }
          STR_ALLOC(&result, tmp + result_pos, &size);
          memcpy(result + result_pos ,new_val_copy, tmp + 1);
          result_pos += tmp;
          done_subst = 1;
        } else { /* remove token (and value if any) */
          result_pos = result_save_pos;
          done_subst = 1;
          removed_tok = 1;
        }
      }
      state=TOK_VALUE;
    } else if( state == TOK_VALUE && space && !quote && !escape) {
      state=TOK_BEGIN;
      if(matched_tok && removed_tok && (c == '\n' || c == ' ') ) continue;
    }
    /* state actions */
    if(state == TOK_BEGIN) {
      result[result_pos++] = (char)c;
    } else if(state == TOK_TOKEN) {
      token[token_pos++] = (char)c;
      result[result_pos++] = (char)c;
    } else if(state == TOK_ENDTOK) {
      result[result_pos++] = (char)c;
    } else if(state == TOK_SEP) {
      result[result_pos++] = (char)c;
    } else if(state==TOK_VALUE) {
      if(!matched_tok) result[result_pos++] = (char)c; /* skip value for matching token */
    }
    escape = (c=='\\' && !escape);
    if(c == '\0') break;
  }
  if(!done_subst) { /* if tok not found add tok=new_val_copy at end */
    if(result_pos == 0 ) result_pos = 1; /* result="" */
    if(new_val_copy) {
      if(!new_val_copy[0]) new_val_copy = "\"\"";
      tmp = strlen(new_val_copy) + strlen(tok) + 2;
      STR_ALLOC(&result, tmp + result_pos, &size);
      if(result_pos > 1 && (result[result_pos - 2] == ' ' || result[result_pos - 2] == '\n')) {
        /* result_pos guaranteed to be > 0 */
        my_snprintf(result + result_pos - 1, size, "%s=%s", tok, new_val_copy );
      } else {
        /* result_pos guaranteed to be > 0 */
        my_snprintf(result + result_pos - 1, size, "\n%s=%s", tok, new_val_copy );
      }
    }
  }
  dbg(2, "subst_token(): returning: %s\n",result);
  my_free(_ALLOC_ID_, &token);
  my_free(_ALLOC_ID_, &new_val_copy);
  return result;
}

const char *get_trailing_path(const char *str, int no_of_dir, int skip_ext)
{
  static char s[PATH_MAX]; /* safe to keep even with multiple schematic windows */
  size_t len;
  size_t ext_pos, dir_pos;
  int n_ext, n_dir, c, i, generator = 0;

  if(str == NULL) return NULL;
  my_strncpy(s, str, S(s));
  len = strlen(s);

  for(ext_pos=len, dir_pos=len, n_ext=0, n_dir=0, i=(int)len; i>=0; i--) {
    c = s[i];
    if(c=='.' && ++n_ext == 1) {
      if(!generator) ext_pos = i;
      if(generator) s[i] = '_';
    }
    if(c=='/' && ++n_dir==no_of_dir+1) dir_pos = i;
    if(c=='(') generator = 1;
  }
  if(skip_ext) s[ext_pos] = '\0';

  if(dir_pos==len) return s;
  dbg(2, "get_trailing_path(): str=%s, no_of_dir=%d, skip_ext=%d\n",
                   str, no_of_dir, skip_ext);
  dbg(2, "get_trailing_path(): returning: %s\n", s+(dir_pos<len ? dir_pos+1 : 0));
  return s+(dir_pos<len ? dir_pos+1 : 0);
}

/* no extension */
const char *get_cell(const char *str, int no_of_dir)
{
  return get_trailing_path(str, no_of_dir, 1);
}

/* keep extension */
const char *get_cell_w_ext(const char *str, int no_of_dir)
{
  return get_trailing_path(str, no_of_dir, 0);
}

/* in a string with tokens separated by characters in 'sep'
 * count number of tokens. Multiple separators and leading/trailing
 * separators are allowed. */
int count_items(const char *s, const char *sep, const char *quote)
{
  const char *ptr;
  int items = 0;
  int state = 0; /* 1 if item is being processed */
  int c, q = 0, e = 0;

  ptr = s;
  while( (c = *(unsigned char *)ptr++) ) {
    if(!e && c == '\\') {
      e = 1;
      continue;
    }
    if(!e && strchr(quote, c)) q = !q;
    if(e || q || !strchr(sep, c)) { /* not a separator */
      if(!state) items++;
      state = 1;
    } else {
      state = 0;
    }
    e = 0;
  }
  dbg(1, "count_items: s=%s, items=%d\n", s, items);
  return items;
}

void print_vhdl_element(FILE *fd, int inst)
{
  int i=0, multip, tmp, tmp1;
  const char *str_ptr;
  register int c, state=TOK_BEGIN, space;
  const char *lab;
  char *name=NULL;
  char  *generic_value=NULL, *generic_type=NULL;
  char *template=NULL,*s, *value=NULL,  *token=NULL;
  int no_of_pins=0, no_of_generics=0;
  size_t sizetok=0, sizeval=0;
  size_t token_pos=0, value_pos=0;
  int quote=0;
  int escape=0;
  xRect *pinptr;
  const char *fmt_attr = NULL;
  Int_hashtable table = {NULL, 0};
  const char *fmt;

  fmt_attr = xctx->format ? xctx->format : "vhdl_format";

  /* allow format string override in instance */
  fmt = get_tok_value(xctx->inst[inst].prop_ptr, fmt_attr, 2);
  /* get netlist format rule from symbol */
  if(!xctx->tok_size)
    fmt = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, fmt_attr, 2);
  /* allow format string override in instance */
  if(!xctx->tok_size && strcmp(fmt_attr, "vhdl_format") )
    fmt = get_tok_value(xctx->inst[inst].prop_ptr, "vhdl_format", 2);
  /* get netlist format rule from symbol */
  if(!xctx->tok_size && strcmp(fmt_attr, "vhdl_format"))
    fmt = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "vhdl_format", 2);

  if(fmt[0]) {
   print_vhdl_primitive(fd, inst);
   return;
  }
  my_strdup(_ALLOC_ID_, &name,xctx->inst[inst].instname);
  if(!name) my_strdup(_ALLOC_ID_, &name, get_tok_value(template, "name", 0));
  if(name==NULL) {
    my_free(_ALLOC_ID_, &name);
    return;
  }
  my_strdup(_ALLOC_ID_, &template, (xctx->inst[inst].ptr + xctx->sym)->templ);
  no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
  no_of_generics= (xctx->inst[inst].ptr + xctx->sym)->rects[GENERICLAYER];

  s=xctx->inst[inst].prop_ptr;

 /* print instance name and subckt */
  dbg(2, "print_vhdl_element(): printing inst name & subcircuit name\n");
  if( (lab = expandlabel(name, &tmp)) != NULL)
    fprintf(fd, "%d %s : %s\n", tmp, lab, sanitize(translate(inst, get_sym_name(inst, 0, 0, 0))) );
  else  /*  name in some strange format, probably an error */
    fprintf(fd, "1 %s : %s\n", name, sanitize(translate(inst, get_sym_name(inst, 0, 0, 0))) );
  dbg(2, "print_vhdl_element(): printing generics passed as properties\n");


  /* -------- print generics passed as properties */

  tmp=0;
  /* 20080213 use generic_type property to decide if some properties are strings, see later */
  my_strdup(_ALLOC_ID_, &generic_type, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr,"generic_type", 0));

  while(1)
  {
    if (s==NULL) break;
   c=*s++;
   if(c=='\\') {
     escape=1;
     c=*s++;
   }
   else
    escape=0;
   space=SPACE(c);
   if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
   else if( state==TOK_TOKEN && space) state=TOK_ENDTOK;
   else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
   else if( state==TOK_SEP && !space) state=TOK_VALUE;
   else if( state==TOK_VALUE && space && !quote) state=TOK_END;
   STR_ALLOC(&value, value_pos, &sizeval);
   STR_ALLOC(&token, token_pos, &sizetok);
   if(state==TOK_TOKEN) token[token_pos++]=(char)c;
   else if(state==TOK_VALUE) {
     if(c=='"' && !escape) quote=!quote;
     else value[value_pos++]=(char)c;
   }
   else if(state==TOK_ENDTOK || state==TOK_SEP) {
     if(token_pos) {
       token[token_pos]='\0';
       token_pos=0;
     }
   } else if(state==TOK_END) {
     value[value_pos]='\0';
     value_pos=0;
     get_tok_value(template, token, 0);
     if(xctx->tok_size) {
       if(strcmp(token, "name") && value[0] != '\0') /* token has a value */
       {
         if(tmp == 0) {fprintf(fd, "generic map(\n");tmp++;tmp1=0;}
         if(tmp1) fprintf(fd, " ,\n");

         /* 20080213  put "" around string type generics! */
         if( generic_type && !strcmp(get_tok_value(generic_type,token, 0), "string")  ) {
           fprintf(fd, "  %s => \"%s\"", token, value);
         } else {
           fprintf(fd, "  %s => %s", token, value);
         }
         /* /20080213 */

         tmp1=1;
       }
     }
     state=TOK_BEGIN;
   }
   if(c=='\0')  /* end string */
   {
    break ;
   }
  }

  /* -------- end print generics passed as properties */
      dbg(2, "print_vhdl_element(): printing generic maps \n");

     /* print generic map */
     for(i=0;i<no_of_generics; ++i)
     {
       if(!xctx->inst[inst].node || !xctx->inst[inst].node[no_of_pins+i]) continue;
       my_strdup(_ALLOC_ID_, &generic_type,
         get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[GENERICLAYER][i].prop_ptr,"type",0));
       my_strdup(_ALLOC_ID_, &generic_value,   xctx->inst[inst].node[no_of_pins+i] );
       /*my_strdup(_ALLOC_ID_, &generic_value, get_tok_value( */
       /*  (xctx->inst[inst].ptr + xctx->sym)->rect[GENERICLAYER][i].prop_ptr,"value") ); */
       str_ptr =
         get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[GENERICLAYER][i].prop_ptr,"name",0);
    if(generic_value) {                  /*03062002 dont print generics if unassigned */
       if(tmp) fprintf(fd, " ,\n");
       if(!tmp) fprintf(fd, "generic map (\n");
       fprintf(fd,"   %s => %s",
                             str_ptr ? str_ptr : "<NULL>",
                             generic_value ? generic_value : "<NULL>"  );
       tmp=1;
    }
  }
  if(tmp) fprintf(fd, "\n)\n");
   dbg(2, "print_vhdl_element(): printing port maps \n");
  /* print port map */
  fprintf(fd, "port map(\n" );
  tmp=0;
  pinptr = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER];
  int_hash_init(&table, 37);
  for(i=0;i<no_of_pins; ++i)
  {
    if(strboolcmp(get_tok_value(pinptr[i].prop_ptr,"vhdl_ignore",0), "true")) {
      const char *name = get_tok_value(pinptr[i].prop_ptr, "name", 0);
      if(!int_hash_lookup(&table, name, 1, XINSERT_NOREPLACE)) {
        if( (str_ptr =  net_name(inst,i, &multip, 0, 1)) )
        {
          if(tmp) fprintf(fd, " ,\n");
          fprintf(fd, "   %s => %s",
            get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][i].prop_ptr,"name",0),
            str_ptr);
          tmp=1;
        }
      }
    }
  }
  int_hash_free(&table);
  fprintf(fd, "\n);\n\n");
   dbg(2, "print_vhdl_element(): ------- end ------ \n");
  my_free(_ALLOC_ID_, &name);
  my_free(_ALLOC_ID_, &generic_value);
  my_free(_ALLOC_ID_, &generic_type);
  my_free(_ALLOC_ID_, &template);
  my_free(_ALLOC_ID_, &value);
  my_free(_ALLOC_ID_, &token);
}

void print_generic(FILE *fd, char *ent_or_comp, int symbol)
{
  int tmp;
  register int c, state=TOK_BEGIN, space;
  char *template=NULL, *s, *value=NULL,  *token=NULL;
  char *type=NULL, *generic_type=NULL, *generic_value=NULL;
  const char *str_tmp;
  int i;
  size_t sizetok=0, sizeval=0;
  size_t token_pos=0, value_pos=0;
  int quote=0;
  int escape=0;
  int token_number=0;

  my_strdup(_ALLOC_ID_, &template, xctx->sym[symbol].templ);
  if( !template || !(template[0]) ) {
    my_free(_ALLOC_ID_, &template);
    return;
  }
  my_strdup(_ALLOC_ID_, &generic_type, get_tok_value(xctx->sym[symbol].prop_ptr,"generic_type",0));
  dbg(2, "print_generic(): symbol=%d template=%s \n", symbol, template);

  fprintf(fd, "%s %s ",ent_or_comp, get_cell(sanitize(xctx->sym[symbol].name), 0));
  if(!strcmp(ent_or_comp,"entity"))
   fprintf(fd, "is\n");
  else
   fprintf(fd, "\n");
  s=template;
  tmp=0;
  while(1)
  {
   c=*s++;
   if(c=='\\')
   {
     escape=1;
     c=*s++;
   }
   else
    escape=0;
   space=SPACE(c);
   if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
   else if( state==TOK_TOKEN && space) state=TOK_ENDTOK;
   else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
   else if( state==TOK_SEP && !space) state=TOK_VALUE;
   else if( state==TOK_VALUE && space && !quote) state=TOK_END;
   STR_ALLOC(&value, value_pos, &sizeval);
   STR_ALLOC(&token, token_pos, &sizetok);
   if(state==TOK_TOKEN) token[token_pos++]=(char)c;
   else if(state==TOK_VALUE)
   {
    if(c=='"' && !escape) quote=!quote;
    else value[value_pos++]=(char)c;
   }
   else if(state==TOK_ENDTOK || state==TOK_SEP) {
     if(token_pos) {
       token[token_pos]='\0';
       token_pos=0;
     }
   } else if(state==TOK_END)                    /* got a token */
   {
    token_number++;
    value[value_pos]='\0';
    value_pos=0;
    my_strdup(_ALLOC_ID_, &type, get_tok_value(generic_type,token,0));

    if(value[0] != '\0') /* token has a value */
    {
     if(token_number>1)
     {
       if(!tmp) {fprintf(fd, "generic (\n");}
       if(tmp) fprintf(fd, " ;\n");
       if(!type || strcmp(type,"string") ) { /* print "" around string values 20080418 check for type==NULL */
         fprintf(fd, "  %s : %s := %s", token, type? type:"integer", value);
       } else {
         fprintf(fd, "  %s : %s := \"%s\"", token, type? type:"integer", value);
       }                                         /* /20080213 */

       tmp=1;
     }
    }
    state=TOK_BEGIN;
   }
   if(c=='\0')  /* end string */
   {
    break ;
   }
  }

  for(i=0;i<xctx->sym[symbol].rects[GENERICLAYER]; ++i)
  {
    my_strdup(_ALLOC_ID_, &generic_type,
       get_tok_value(xctx->sym[symbol].rect[GENERICLAYER][i].prop_ptr,"generic_type",0));
    my_strdup(_ALLOC_ID_, &generic_value,
       get_tok_value(xctx->sym[symbol].rect[GENERICLAYER][i].prop_ptr,"value", 0) );
    str_tmp = get_tok_value(xctx->sym[symbol].rect[GENERICLAYER][i].prop_ptr,"name",0);
    if(!tmp) fprintf(fd, "generic (\n");
    if(tmp) fprintf(fd, " ;\n");
    fprintf(fd,"  %s : %s",str_tmp ? str_tmp : "<NULL>",
                             generic_type ? generic_type : "<NULL>"  );
    if(generic_value &&generic_value[0])
      fprintf(fd," := %s", generic_value);
    tmp=1;
  }
  if(tmp) fprintf(fd, "\n);\n");
  my_free(_ALLOC_ID_, &template);
  my_free(_ALLOC_ID_, &value);
  my_free(_ALLOC_ID_, &token);
  my_free(_ALLOC_ID_, &type);
  my_free(_ALLOC_ID_, &generic_type);
  my_free(_ALLOC_ID_, &generic_value);
}


void print_verilog_param(FILE *fd, int symbol)
{
 register int c, state=TOK_BEGIN, space;
 char *template=NULL, *s, *value=NULL,  *generic_type=NULL, *token=NULL;
 size_t sizetok=0, sizeval=0;
 size_t token_pos=0, value_pos=0;
 int quote=0;
 int escape=0;
 int token_number=0;
 char *extra = NULL;

 my_strdup(_ALLOC_ID_, &template, xctx->sym[symbol].templ); /* 20150409 20171103 */
 if( !template || !(template[0]) )  {
   my_free(_ALLOC_ID_, &template);
   return;
 }
 my_strdup(_ALLOC_ID_, &generic_type, get_tok_value(xctx->sym[symbol].prop_ptr,"generic_type",0));
 my_strdup(_ALLOC_ID_, &extra, get_tok_value(xctx->sym[symbol].prop_ptr,"extra",0) );
 dbg(2, "print_verilog_param(): symbol=%d template=%s \n", symbol, template);

 s=template;
 while(1)
 {
  c=*s++;
  if(c=='\\')
  {
    escape=1;
    c=*s++;
  }
  else
   escape=0;
  space=SPACE(c);
  if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
  else if( state==TOK_TOKEN && space) state=TOK_ENDTOK;
  else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
  else if( state==TOK_SEP && !space) state=TOK_VALUE;
  else if( state==TOK_VALUE && space && !quote) state=TOK_END;

  STR_ALLOC(&value, value_pos, &sizeval);
  STR_ALLOC(&token, token_pos, &sizetok);
  if(state==TOK_TOKEN) token[token_pos++]=(char)c;
  else if(state==TOK_VALUE)
  {
   if(c=='"' && !escape) quote=!quote;
   else value[value_pos++]=(char)c;
  }
  else if(state==TOK_ENDTOK || state==TOK_SEP) {
    if(token_pos) {
      token[token_pos]='\0';
      token_pos=0;
    }
  } else if(state==TOK_END)                    /* got a token */
  {
   token_number++;
   value[value_pos]='\0';
   value_pos=0;

   if(value[0] != '\0') /* token has a value */
   {
    if(token_number>1 && (!extra || !strstr(extra, token)))
    {
      /* 20080915 put "" around string params */
      if( !generic_type || strcmp(get_tok_value(generic_type,token, 0), "time")  ) {
        if( generic_type && !strcmp(get_tok_value(generic_type,token, 0), "string")  ) {
          fprintf(fd, "  parameter   %s = \"%s\" ;\n", token,  value);
        }
        else  {
          fprintf(fd, "  parameter   %s = %s ;\n", token,  value);
        }
      }
    }
   }
   state=TOK_BEGIN;
  }
  if(c=='\0')  /* end string */
  {
   break ;
  }
 }
 my_free(_ALLOC_ID_, &template);
 my_free(_ALLOC_ID_, &generic_type);
 my_free(_ALLOC_ID_, &value);
 my_free(_ALLOC_ID_, &token);
 my_free(_ALLOC_ID_, &extra);
}




void print_tedax_subckt(FILE *fd, int symbol)
{
 int i=0, multip;
 int no_of_pins=0;
 const char *str_ptr=NULL;

  no_of_pins= xctx->sym[symbol].rects[PINLAYER];

  for(i=0;i<no_of_pins; ++i)
  {
    if(strboolcmp(get_tok_value(xctx->sym[symbol].rect[PINLAYER][i].prop_ptr,"tedax_ignore",0), "true")) {
      str_ptr=
        expandlabel(get_tok_value(xctx->sym[symbol].rect[PINLAYER][i].prop_ptr,"name",0), &multip);
      fprintf(fd, "%s ", str_ptr);
    }
  }
}

/* This function is used to generate the @pinlist replacement getting port order
 * from the spice_sym_def attribute (either directly or by loading the provided .include file),
 * checking with the corresponding symbol pin name and getting the net name attached to it.
 * Any name mismatch is reported, in this case the function does nothing and the default xschem
 * symbol port ordering will be used. */
static int has_included_subcircuit(int inst, int symbol, char **result)
{
  char *spice_sym_def = NULL;
  const char *translated_sym_def;
  int ret = 0;


  my_strdup2(_ALLOC_ID_, &spice_sym_def, get_tok_value(xctx->inst[inst].prop_ptr, "spice_sym_def", 2));
  if(!spice_sym_def[0]) {
    my_strdup2(_ALLOC_ID_, &spice_sym_def, get_tok_value(xctx->sym[symbol].prop_ptr, "spice_sym_def", 0));
  }

  if(xctx->tok_size) {
    char *symname = NULL;
    char *symname_attr = NULL;
    int no_of_pins = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    int i;
    int exp_no_of_pins = 0; /* number of single bit ports, ie all buses expanded */
    char *net, *net_save;
    Str_hashentry *entry;
    Str_hashtable table = {NULL, 0};

    my_strdup2(_ALLOC_ID_, &symname, get_tok_value(xctx->inst[inst].prop_ptr, "schematic", 0));
    if(!symname[0]) {
      my_strdup2(_ALLOC_ID_, &symname, get_tok_value(xctx->sym[symbol].prop_ptr, "schematic", 0));
    }
    if(!symname[0]) {
      my_strdup2(_ALLOC_ID_, &symname, xctx->sym[symbol].name);
    }
    /* twin of the site in get_additional_symbols() (actions.c): get_cell() returns ""
     * when the basename is nothing but an extension, and an unquoted empty symname would
     * swallow the " symref=..." that follows. Issue 0183. */
    my_mstrcat_tok(_ALLOC_ID_, &symname_attr, "symname", get_cell(symname, 0), NULL);
    my_mstrcat(_ALLOC_ID_, &symname_attr, " symref=", get_sym_name(inst, 9999, 1, 1), NULL);
    translated_sym_def = translate3(spice_sym_def, 1, xctx->inst[inst].prop_ptr,
                                                      xctx->sym[symbol].templ,
                                                      symname_attr, NULL);
    dbg(1, "has_included_subcircuit(): translated_sym_def=%s\n", translated_sym_def);
    dbg(1, "has_included_subcircuit(): symname=%s\n", symname);

    /* pin list from symbol. Calculate also exp_no_of_pins */
    str_hash_init(&table, 6247);
    for(i = 0;i < no_of_pins; ++i) {
      char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][i].prop_ptr;
      int spice_ignore = !strboolcmp(get_tok_value(prop, "spice_ignore", 0), "true");
      const char *name = get_tok_value(prop, "name", 0);
      if(!spice_ignore) {
        char *pin, *pin_save;
        int pin_mult, net_mult;
        char *pin_expanded_ptr, *pin_expanded = NULL;
        char *net_expanded_ptr, *net_expanded = NULL;
        my_strdup2(_ALLOC_ID_, &pin_expanded, expandlabel(name, &pin_mult));
        exp_no_of_pins += pin_mult;
        strtolower(pin_expanded);
        my_strdup2(_ALLOC_ID_, &net_expanded, net_name(inst, i, &net_mult, 0, 1));
        net_expanded_ptr = net_expanded;
        pin_expanded_ptr = pin_expanded;
        while((pin = my_strtok_r(pin_expanded_ptr, ",", "", 0, &pin_save))) {
          net = my_strtok_r(net_expanded_ptr, ",", "", 0, &net_save);
          str_hash_lookup(&table, pin, net ? net : "<NULL>", XINSERT_NOREPLACE);
          dbg(1, "inserting pin: %s, net: %s\n", pin, net ? net : "<NULL>");
          pin_expanded_ptr = NULL;
          net_expanded_ptr = NULL;
        }
        my_free(_ALLOC_ID_, &pin_expanded);
        my_free(_ALLOC_ID_, &net_expanded);
      }
    }
    dbg(1, "exp_no_of_pins=%d\n", exp_no_of_pins);
    /* process spice_sym_def spice netlist */
    strtolower(symname);
    /* the cell name and the `spice_sym_def` attribute are both `.sym` text
     * (issue 0817 Z.4); the pin count is a decimal the C side formatted */
    tcl_call("has_included_subcircuit", get_cell(symname, 0), translated_sym_def,
             my_itoa(exp_no_of_pins));

    my_free(_ALLOC_ID_, &symname_attr);
    if(tclresult()[0]) { /* a valid spice_sym_def netlist was found */
      char *subckt_pin, *pin_save;
      char *subckt_pinlist_ptr;
      char *subckt_pinlist = NULL;
      char *tmp_result = NULL;
      int symbol_pins = 0;
      int instance_pins = 0;

      my_strdup2(_ALLOC_ID_, &subckt_pinlist, tclresult());
      dbg(1, "included subcircuit: pinlist=%s\n", subckt_pinlist);


      /* list from subcircuit netlist */
      subckt_pinlist_ptr = subckt_pinlist;
      while( (subckt_pin = my_strtok_r(subckt_pinlist_ptr, " ", "", 0, &pin_save)) ) {
        instance_pins++;
        entry = str_hash_lookup(&table, subckt_pin, NULL, XLOOKUP);
        if(entry) {
          const char *net;
          net = entry->value;
          symbol_pins++;
          dbg(1, "subckt_pin=%s, net=%s\n", subckt_pin, net);
          my_mstrcat(_ALLOC_ID_, &tmp_result, "?1 ", net, " ", NULL);
        }
        subckt_pinlist_ptr = NULL;
      }

      /* check if they match */
      if(instance_pins == symbol_pins) {
        ret = 1;
        my_mstrcat(_ALLOC_ID_, result, tmp_result, NULL);
      } else {
        dbg(0, "has_included_subcircuit(): %s symbol and .subckt pins do not match. Discard port order\n",
                symname);
        if(has_x) {
          char amsg[PATH_MAX + 200];
          my_snprintf(amsg, S(amsg), "has_included_subcircuit(): %s symbol and .subckt pins"
              " do not match. Discard .subckt port order", symname);
          tcl_call("alert_", amsg, NULL, NULL);
        }
      }
      if(tmp_result) my_free(_ALLOC_ID_, &tmp_result);
      my_free(_ALLOC_ID_, &subckt_pinlist);
    }
    my_free(_ALLOC_ID_, &symname);
    str_hash_free(&table);
  }
  my_free(_ALLOC_ID_, &spice_sym_def);
  return ret;
}

void print_spice_subckt_nodes(FILE *fd, int symbol)
{
 int i=0, multip;
 const char *str_ptr=NULL;
 register int c, state=TOK_BEGIN, space;
 char *format=NULL, *format1 = NULL, *s, *token=NULL;
 int pin_number;
 size_t sizetok=0;
 size_t token_pos=0;
 int escape=0;
 int no_of_pins=0;
 char *result = NULL;
 const char *tclres, *fmt_attr = NULL;

 fmt_attr = xctx->format ? xctx->format : "format";
 my_strdup(_ALLOC_ID_, &format1, get_tok_value(xctx->sym[symbol].prop_ptr, fmt_attr, 2));
 if(!xctx->tok_size && strcmp(fmt_attr, "format") )
   my_strdup(_ALLOC_ID_, &format1, get_tok_value(xctx->sym[symbol].prop_ptr, "format", 2));
 dbg(1, "print_spice_subckt(): format1=%s\n", format1);

 /* can not do this, since @symname is used as a token later in format parser */
 /* my_strdup(_ALLOC_ID_, &format1,
  * str_replace(format1, "@symname", get_cell(xctx->sym[symbol].name, 0), '\\', -1)); */

 if(format1 && strstr(format1, "tcleval(") == format1) {
    tclres = tcl_hook2(format1);
    if(!strcmp(tclres, "?\n")) {
      char *ptr = strrchr(format1 + 8, ')');
      *ptr = '\0';
      my_strdup(_ALLOC_ID_, &format,  format1 + 8);
    } else my_strdup(_ALLOC_ID_, &format,  tclres);
 } else {
   my_strdup(_ALLOC_ID_, &format,  format1);
 }
 if(format1) my_free(_ALLOC_ID_, &format1);
 dbg(1, "print_spice_subckt(): format=%s\n", format);
 if( format==NULL ) {
   return; /* no format */
 }
 no_of_pins= xctx->sym[symbol].rects[PINLAYER];
 s=format;

 /* begin parsing format string */
 while(1)
 {
  c=*s++;
  if(c=='\\') {
    escape=1;
    c=*s++;
  }
  else escape=0;
  if(c=='\n' && escape ) c=*s++; /* 20171030 eat escaped newlines */
  space=SPACE(c);
  if( state==TOK_BEGIN && (c=='@' || c=='%')  && !escape) state=TOK_TOKEN;
  else if(state==TOK_TOKEN && token_pos > 1 &&
     (
       ( (space  || c == '%' || c == '@') && !escape ) ||
       ( (!space && c != '%' && c != '@') && escape  )
     )
    ) {
    state = TOK_SEP;
  }

  STR_ALLOC(&token, token_pos, &sizetok);
  if(state==TOK_TOKEN) {
    token[token_pos++]=(char)c;
  }
  else if(state==TOK_SEP)                    /* got a token */
  {
   token[token_pos]='\0';
   token_pos=0;
   if(!strcmp(token, "@spiceprefix")) {
     /* do nothing */
   }
   else if(!strcmp(token, "@name")) {
     /* do nothing */
   }
   else if(strcmp(token, "@symname")==0) {
     break ;
   }
   else if(strcmp(token, "@model")==0) {
     break ;
   }
   else if(strcmp(token, "@pinlist")==0) {
     Int_hashtable table = {NULL, 0};
     int_hash_init(&table, 37);
     for(i=0;i<no_of_pins; ++i)
     {
       if(strboolcmp(get_tok_value(xctx->sym[symbol].rect[PINLAYER][i].prop_ptr,"spice_ignore",0), "true")) {
         const char *name = get_tok_value(xctx->sym[symbol].rect[PINLAYER][i].prop_ptr,"name",0);
         if(!int_hash_lookup(&table, name, 1, XINSERT_NOREPLACE)) {
           str_ptr= expandlabel(name, &multip);
           /* fprintf(fd, "%s ", str_ptr); */
           my_mstrcat(_ALLOC_ID_, &result, str_ptr, " ", NULL);
         }
       }
     }
     int_hash_free(&table);
   }
   else if(token[0]=='@' && token[1]=='@') {    /* recognize single pins 15112003 */
     char *prop=NULL;
     for(i = 0; i<no_of_pins; ++i) {
       prop = xctx->sym[symbol].rect[PINLAYER][i].prop_ptr;
       if(!strcmp(get_tok_value(prop, "name",0), token + 2)) break;
     }
     if(i<no_of_pins && strboolcmp(get_tok_value(prop,"spice_ignore",0), "true")) {
       /* fprintf(fd, "%s ", expandlabel(token+2, &multip)); */
       my_mstrcat(_ALLOC_ID_, &result, expandlabel(token+2, &multip), " ", NULL);
     }
   }
   /* reference by pin number instead of pin name, allows faster lookup of the attached net name 20180911 */
   else if(token[0]=='@' && token[1]=='#') {
     char *pin_attr = NULL;
     char *pin_num_or_name = NULL;
     get_pin_and_attr(token, &pin_num_or_name, &pin_attr);
     pin_number = get_sym_pin_number(symbol, pin_num_or_name);
     if(pin_number >= 0 && pin_number < no_of_pins) {
       if(strboolcmp(get_tok_value(xctx->sym[symbol].rect[PINLAYER][pin_number].prop_ptr,"spice_ignore",0), "true")) {
       str_ptr =  get_tok_value(xctx->sym[symbol].rect[PINLAYER][pin_number].prop_ptr,"name",0);
       /* fprintf(fd, "%s ",  expandlabel(str_ptr, &multip)); */
       my_mstrcat(_ALLOC_ID_, &result, expandlabel(str_ptr, &multip), " ", NULL);
       }
     }
     my_free(_ALLOC_ID_, &pin_attr);
     my_free(_ALLOC_ID_, &pin_num_or_name);

   }
   /* this will print the other @parameters, usually "extra" nodes so they will be in the order
    * specified by the format string. The 'extra' attribute is no more used to print extra nodes
    * in spice_block_netlist(). */
   else if(token[0] == '@') { /* given previous if() conditions not followed by @ or # */
     /* if token not followed by white space it is not an extra node */
     if( ( (space  || c == '%' || c == '@') && !escape ) ) {
       /* fprintf(fd, "%s ",  token + 1); */
       my_mstrcat(_ALLOC_ID_, &result, token + 1, " ", NULL);
     }
   }
   /* if(c!='%' && c!='@' && c!='\0' ) fputc(c,fd); */
   if(c == '@' || c =='%') s--;
   state=TOK_BEGIN;
  }
                 /* 20151028 dont print escaping backslashes */
  else if(state==TOK_BEGIN && c!='\0') {
   /* do nothing */
  }
  if(c=='\0')
  {
   my_mstrcat(_ALLOC_ID_, &result, "\n", NULL);
   break ;
  }
 }
 if(result) {
   fprintf(fd, "%s", result);
   my_free(_ALLOC_ID_, &result);
 }
 my_free(_ALLOC_ID_, &format1);
 my_free(_ALLOC_ID_, &format);
 my_free(_ALLOC_ID_, &token);
}


void print_spectre_subckt_nodes(FILE *fd, int symbol)
{
 int i=0, multip;
 const char *str_ptr=NULL;
 register int c, state=TOK_BEGIN, space;
 char *format=NULL, *format1 = NULL, *s, *token=NULL;
 int pin_number;
 size_t sizetok=0;
 size_t token_pos=0;
 int escape=0;
 int no_of_pins=0;
 char *result = NULL;
 const char *tclres, *fmt_attr = NULL;

 fmt_attr = xctx->format ? xctx->format : "spectre_format";
 my_strdup(_ALLOC_ID_, &format1, get_tok_value(xctx->sym[symbol].prop_ptr, fmt_attr, 2));
 if(!xctx->tok_size && strcmp(fmt_attr, "spectre_format") )
   my_strdup(_ALLOC_ID_, &format1, get_tok_value(xctx->sym[symbol].prop_ptr, "spectre_format", 2));
 dbg(1, "print_spectre_subckt(): format1=%s\n", format1);

 /* can not do this, since @symname is used as a token later in format parser */
 /* my_strdup(_ALLOC_ID_, &format1,
  * str_replace(format1, "@symname", get_cell(xctx->sym[symbol].name, 0), '\\', -1)); */

 if(format1 && strstr(format1, "tcleval(") == format1) {
    tclres = tcl_hook2(format1);
    if(!strcmp(tclres, "?\n")) {
      char *ptr = strrchr(format1 + 8, ')');
      *ptr = '\0';
      my_strdup(_ALLOC_ID_, &format,  format1 + 8);
    } else my_strdup(_ALLOC_ID_, &format,  tclres);
 } else {
   my_strdup(_ALLOC_ID_, &format,  format1);
 }
 if(format1) my_free(_ALLOC_ID_, &format1);
 dbg(1, "print_spectre_subckt(): format=%s\n", format);
 if( format==NULL ) {
   return; /* no format */
 }
 no_of_pins= xctx->sym[symbol].rects[PINLAYER];
 s=format;

 /* begin parsing format string */
 while(1)
 {
  c=*s++;
  if(c=='\\') {
    escape=1;
    c=*s++;
  }
  else escape=0;
  if(c=='\n' && escape ) c=*s++; /* 20171030 eat escaped newlines */
  space=SPACE(c);
  if( state==TOK_BEGIN && (c=='@' || c=='%')  && !escape) state=TOK_TOKEN;
  else if(state==TOK_TOKEN && token_pos > 1 &&
     (
       ( (space  || c == '%' || c == '@') && !escape ) ||
       ( (!space && c != '%' && c != '@') && escape  )
     )
    ) {
    state = TOK_SEP;
  }

  STR_ALLOC(&token, token_pos, &sizetok);
  if(state==TOK_TOKEN) {
    token[token_pos++]=(char)c;
  }
  else if(state==TOK_SEP)                    /* got a token */
  {
   token[token_pos]='\0';
   token_pos=0;
   if(!strcmp(token, "@spiceprefix")) {
     /* do nothing */
   }
   else if(!strcmp(token, "@name")) {
     /* do nothing */
   }
   else if(strcmp(token, "@symname")==0) {
     break ;
   }
   else if(strcmp(token, "@model")==0) {
     break ;
   }
   else if(strcmp(token, "@pinlist")==0) {
     Int_hashtable table = {NULL, 0};
     int_hash_init(&table, 37);
     for(i=0;i<no_of_pins; ++i)
     {
       if(strboolcmp(get_tok_value(xctx->sym[symbol].rect[PINLAYER][i].prop_ptr,"spectre_ignore",0), "true")) {
         const char *name = get_tok_value(xctx->sym[symbol].rect[PINLAYER][i].prop_ptr,"name",0);
         if(!int_hash_lookup(&table, name, 1, XINSERT_NOREPLACE)) {
           str_ptr= expandlabel(name, &multip);
           /* fprintf(fd, "%s ", str_ptr); */
           my_mstrcat(_ALLOC_ID_, &result, str_ptr, " ", NULL);
         }
       }
     }
     int_hash_free(&table);
   }
   else if(token[0]=='@' && token[1]=='@') {    /* recognize single pins 15112003 */
     char *prop=NULL;
     for(i = 0; i<no_of_pins; ++i) {
       prop = xctx->sym[symbol].rect[PINLAYER][i].prop_ptr;
       if(!strcmp(get_tok_value(prop, "name",0), token + 2)) break;
     }
     if(i<no_of_pins && strboolcmp(get_tok_value(prop,"spectre_ignore",0), "true")) {
       /* fprintf(fd, "%s ", expandlabel(token+2, &multip)); */
       my_mstrcat(_ALLOC_ID_, &result, expandlabel(token+2, &multip), " ", NULL);
     }
   }
   /* reference by pin number instead of pin name, allows faster lookup of the attached net name 20180911 */
   else if(token[0]=='@' && token[1]=='#') {
     char *pin_attr = NULL;
     char *pin_num_or_name = NULL;
     get_pin_and_attr(token, &pin_num_or_name, &pin_attr);
     pin_number = get_sym_pin_number(symbol, pin_num_or_name);
     if(pin_number >= 0 && pin_number < no_of_pins) {
       if(strboolcmp(get_tok_value(xctx->sym[symbol].rect[PINLAYER][pin_number].prop_ptr,"spectre_ignore",0), "true")) {
       str_ptr =  get_tok_value(xctx->sym[symbol].rect[PINLAYER][pin_number].prop_ptr,"name",0);
       /* fprintf(fd, "%s ",  expandlabel(str_ptr, &multip)); */
       my_mstrcat(_ALLOC_ID_, &result, expandlabel(str_ptr, &multip), " ", NULL);
       }
     }
     my_free(_ALLOC_ID_, &pin_attr);
     my_free(_ALLOC_ID_, &pin_num_or_name);

   }
   /* this will print the other @parameters, usually "extra" nodes so they will be in the order
    * specified by the format string. The 'extra' attribute is no more used to print extra nodes
    * in spice_block_netlist(). */
   else if(token[0] == '@') { /* given previous if() conditions not followed by @ or # */
     /* if token not followed by white space it is not an extra node */
     if( ( (space  || c == '%' || c == '@') && !escape ) ) {
       /* fprintf(fd, "%s ",  token + 1); */
       my_mstrcat(_ALLOC_ID_, &result, token + 1, " ", NULL);
     }
   }
   /* if(c!='%' && c!='@' && c!='\0' ) fputc(c,fd); */
   if(c == '@' || c =='%') s--;
   state=TOK_BEGIN;
  }
                 /* 20151028 dont print escaping backslashes */
  else if(state==TOK_BEGIN && c!='\0') {
   /* do nothing */
  }
  if(c=='\0')
  {
   my_mstrcat(_ALLOC_ID_, &result, "\n", NULL);
   break ;
  }
 }
 if(result) {
   fprintf(fd, "%s", result);
   my_free(_ALLOC_ID_, &result);
 }
 my_free(_ALLOC_ID_, &format1);
 my_free(_ALLOC_ID_, &format);
 my_free(_ALLOC_ID_, &token);
}

int has_token(const char *s, const char *tok)
{
  int i = 1;
  int ret = 0;
  char *item;

  while(1) {
    item = find_nth(s, " ", "", 1, i);
    dbg(1, "item=%s, tok=%s\n", item, tok);
    if(!item[0]) break;
    else if(!strcmp(tok, item)) {
      ret = 1;
      break;
    }
    i++;
  }
  return ret;
}

/* ERC for issue 0165: an `extra=`-declared NODE bound to a name starting with '#'.
 *
 * '#' is the engine's private marker for an auto-named net. A wire LABELLED `#foo`
 * netlists as plain `foo` -- every wire/instance connection goes through net_name(),
 * which strips. But an `extra=` binding is a "hidden pin" passed as an instance
 * ATTRIBUTE, and its resolved value is written onto the subcircuit call line VERBATIM
 * (print_spice_element's generic @token branch, and print_spectre_element's). So one
 * spelling the user wrote once becomes two unconnected nodes -- measured, ngspice-42:
 * `X1 topn #hfoo c` and `R9 hfoo 0 1k` give `hfoo` 0.0V and `#hfoo` 1.0V in one deck.
 *
 * Decided (0165 D1-D4): WARN, do not rewrite. Stripping here would not actually fix
 * the shape -- the child's .subckt PORT list keeps its own '#' too (token.c:2098,
 * spice_netlist.c:375), so the port would still be split from its body -- and it would
 * change netlist output at ~15 emission sites across five backends. The warning covers
 * all of them at once and is output-neutral.
 *
 * LOOSE, and in the same style/severity as the existing '#'-name warning at
 * netlist.c:1491: warn on any leading '#' that is NOT the engine's own "#net<N>". The
 * two warnings are complements -- that one fires on the LABEL half of this trap and
 * cannot reach the binding half, because it sits behind an IS_LABEL_OR_PIN gate reading
 * inst[i].node[0], a slot a binding never occupies.
 *
 * Take the RESOLVED value, not get_tok_value(prop_ptr, tok, 0): the value is produced by
 * up to four translate3() rounds and may come from `HN=@FOO` forwarding, a template
 * default, the containing cell's template, or an expr(). Reading the raw attribute would
 * miss every one of those.
 *
 * Gate on the symbol's extra= list so this stays a check about NODES rather than about
 * every instance parameter -- a `model=#foo` is not a net and is not our business.
 * attr_is_extra_node() is hilight.c's, shared deliberately: resolved_net() and this must
 * agree on what "extra= declares a node" means.
 *
 * A binding may be a bus, so check every comma-separated element (issue 0158 established
 * that a '#' hides per element, not only at the head of the value). */
static void warn_hash_extra_node(int inst, const char *tokname, const char *value)
{
  const char *extra, *p, *e;
  char elem[256];
  char str[2048];
  size_t n;
  size_t saved_tok_size;

  if(!tokname || !tokname[0] || !value || !value[0]) return;
  if(!strchr(value, '#')) return;                     /* cheap reject: the common case */
  /* get_tok_value() overwrites xctx->tok_size, which the callers use as their
   * "token ABSENT" signal. They both latch it into token_exists BEFORE calling here,
   * so this is safe today -- restore it anyway so an ERC observer can never become
   * the reason a netlist value goes missing if the call site ever moves. */
  saved_tok_size = xctx->tok_size;
  extra = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "extra", 0);
  if(!attr_is_extra_node(extra, tokname)) { xctx->tok_size = saved_tok_size; return; }
  xctx->tok_size = saved_tok_size;
  p = value;
  while(*p) {
    e = p;
    while(*e && *e != ',') ++e;
    if(*p == '#') {
      n = (size_t)(e - p);
      if(n >= sizeof(elem)) n = sizeof(elem) - 1;
      memcpy(elem, p, n);
      elem[n] = '\0';
      if(!is_auto_net_name(elem)) {
        my_snprintf(str, S(str),
          "Warning: instance: %s: attribute %s=%s binds a node whose name starts with '#', "
          "which is reserved for auto-named nets: the binding reaches the netlist verbatim "
          "while a wire labelled the same way is stripped, so the two are DIFFERENT nodes",
          xctx->inst[inst].instname ? xctx->inst[inst].instname : "?", tokname, elem);
        statusmsg(str, 2);
      }
    }
    p = *e ? e + 1 : e;
  }
}

/* ISSUE 0970: THE SETTINGS A USER TYPES ON A SHEET THAT NEVER REACH THE DECK.
 *
 * A designer clicks a cell on their schematic and types `modelp=pfet_01v8_lvt`
 * on it, meaning "build THIS copy of the cell out of the low-threshold device".
 * If the symbol's format= string never mentions modelp, the netlister writes
 * ONE .subckt body for every copy of that cell out of the SYMBOL TEMPLATE's own
 * default, and the setting the user typed is discarded without a word. Measured
 * on the shipped sky130_tests bandgap bench before this pass: one `.subckt
 * passgate` body, zero occurrences of `modelp` anywhere in the deck, and two
 * transistors that had never once been simulated as the device their schematic
 * line names.
 *
 * THE SILENCE IS THE DEFECT, not the dropping. The netlister finds the breath
 * to warn about an open net on that very sheet; about the setting it threw away
 * it said nothing, ever, on any sheet.
 *
 * WHY THIS IS NARROWED RATHER THAN GENERAL, with the measurement. Run over
 * every schematic in both shipped PDK trees (321 sheets, 13630 instances), the
 * unnarrowed rule -- "any instance attribute the format string does not use" --
 * emits 16876 lines. That is not a diagnostic, it is wallpaper, and a warning
 * nobody can read is worse than no warning at all. Each guard below is the
 * reason a number that large becomes a number a person can act on; the counts
 * are recorded in doc/claude/issues/0970-*.md.
 *
 * ISSUE 0980, THE CORRECTION. The first version of this check asked only
 * whether the SPICE format string referenced the property, and shipped ON BY
 * DEFAULT. Netlisting the whole of xschem_library to SPICE, it printed 149
 * lines on 18 sheets and 43 of them were false; on six of those sheets every
 * line was false. The missing half was that a symbol is netlisted in six
 * formats and that VHDL and Verilog pass an instance attribute in as a
 * generic/parameter on the strength of the SYMBOL TEMPLATE, no format string
 * involved. GUARD UA-TMPL and GUARD UA-ALTFMT below are that half; the same
 * sweep after them is recorded in doc/claude/issues/0980-*.md.
 *
 * ISSUES 0987 AND 0988, THE SECOND CORRECTION, AND WHY THERE ARE TWO SENTENCES
 * NOW. The 0980 pass asked ONE question -- "can ANY netlist of this cell use
 * this setting?" -- and went silent whenever the answer was yes. That turned 43
 * wrong accusations into 43 silences, one for one: shipped
 * xschem_library/examples/loading.sch types cap=100.0, 30.0, 20.0 and 40.0 on
 * four capacitors, the SPICE deck writes one `.subckt real_capa USC  cap=10.0`
 * and none of those four numbers appears in it anywhere, so all four simulate
 * at 10.0 -- and the tool said nothing whatever. The honest question is BOTH:
 * can any format use it, AND does the format being written right now use it.
 * ua_reach() below answers in three states, and the sentence has two shapes.
 * A reader would assume "not a mistake" and "silent" are the same thing. They
 * are opposites here: one of them costs the designer their setting.
 *
 * DELIBERATELY NOT IN THE STOPLIST: `schematic` and the *_sym_def family. Those
 * are guard UA-POLY's business, one block down, because for them the override
 * really does reach the deck and the instance must be skipped ENTIRELY -- not
 * merely have one attribute excused. Keeping them out of the list keeps the two
 * guards separately visible, and separately sabotage-able.
 *
 * A reader would otherwise assume every name here is arbitrary. They are not:
 * each is either a netlist-time attribute the backends read for themselves
 * (device_model is hashed straight off the instance at spice_netlist.c:235-241,
 * outside any format string -- measured, 2 false hits on devices/vsource
 * without it), an ERC/LVS directive, or a drawing/GUI attribute that was never
 * going to appear in a deck.
 *
 * `select` USED TO BE THE LAST OF THOSE AND IS NOT ON THIS LIST ANY MORE --
 * issue 0989. It moved to unused_attr_cellparam_stoplist just below, which asks
 * the question per CELL rather than per NAME. That list records why the other
 * 55 names deliberately did not move with it. */
static const char * const unused_attr_stoplist[] = {
  "name", "lab", "sig_type", "verilog_type", "verilog_gate",
  "spice_ignore", "vhdl_ignore", "verilog_ignore", "tedax_ignore",
  "spectre_ignore", "lvs_ignore", "lvs_netlist", "only_toplevel",
  "embed", "url", "symversion", "place", "hide", "hide_texts",
  "locked", "lock", "comment", "text", "tclcommand", "analysis",
  "format", "spice_format", "vhdl_format", "verilog_format",
  "tedax_format", "spectre_format", "extra", "extra_pinnumber",
  "numslots", "sim_pinnumber", "pinnumber", "spiceprefix",
  "highlight", "net_name", "propag", "dir", "global",
  "generic_type", "template", "device_model", "spectre_device_model",
  "model-name", "attach", "program", "file", "class", "savecurrent",
  "top_is_subckt", "hiersep", "bus_replacement_char",
  NULL
};

/* GUARD UA-STOP2, issue 0989. The names above are excused WHATEVER cell they
 * are typed on. This second list is excused only while the cell does NOT
 * declare the name as one of its own parameters.
 *
 * THE CAUSE OF 0989 IS NOT A KEYWORD AND NOT A TCL OR C LIST COMMAND, which is
 * what a reader -- and the issue as filed -- would assume from the symptom. It
 * is a plain case-sensitive strcmp() against the list above, applied to the
 * ATTRIBUTE NAME alone with no regard for the cell. Measured on one instance
 * carrying ten settings the cell reads nothing of: `select`, `dir`, `class` and
 * `global` were silent while `selectt`, `dirr`, `classs`, `globall`, `Select`
 * (the same word with a capital S) and `knobx` were every one of them reported.
 * One extra letter, or one capital, and the tool speaks. So `select` was never
 * special: it was one of 56 doors, and a designer who names a real subcircuit
 * parameter after any of those words could never be told their setting went
 * nowhere, however the cell was written.
 *
 * WHEN A NAME BELONGS ON THIS LIST RATHER THAN THE ONE ABOVE: when the only
 * thing that reads it is a UI convenience OUTSIDE any netlist, so a symbol
 * author who declares it in template= has the stronger claim to the name.
 * `select` is read by the property editor to decide which field to put the
 * cursor in (src/property_form.tcl, `xschem get_tok $::tctx::retval select`),
 * and shipped xschem_library/ngspice/solar_panel.sch sets select=OFFSET and
 * select=AMPLITUDE on two comparators for exactly that. comp_ngspice.sym's
 * template declares no `select`, so those two stay silent -- while a mux whose
 * template DOES declare one is now reportable, which is the whole of 0989.
 *
 * THE OTHER 55 DELIBERATELY DID NOT MOVE, and a blanket rule would manufacture
 * false positives on shipped data. Thirteen of them are already declared in
 * some shipped symbol's template while no shipped format string reads them --
 * numslots by 271 symbols, class by 67, symversion by 48, only_toplevel by 20,
 * model-name by 20, file by 11, comment by 9, sig_type by 5, text, spice_ignore,
 * generic_type, device_model and bus_replacement_char by one or two each. The
 * netlister, loader and drawing code read those off the instance whether or not
 * the cell declares them, so the cell's template says nothing about whether the
 * setting was consumed. Recorded as a rule debt on issue 0989. */
static const char * const unused_attr_cellparam_stoplist[] = {
  "select",
  NULL
};

/* GUARD UA-FMT, issue 0970. Does <format> reference <tok> as @tok or %tok?
 *
 * WHOLE-TOKEN, NEVER strstr(). A reader would assume a substring test is good
 * enough here; it is the exact defect this check exists to catch, in a new
 * place. passgate.sym's format carries `W_P=@W_P`, so a plain strstr() for "W"
 * finds it and the diagnostic goes quiet about an instance that really did set
 * a stray `W` -- one name hiding inside another, which is how issue 0972 was
 * filed one layer down. So the character after the match must not continue the
 * identifier. */
static int format_uses_token(const char *format, const char *tok)
{
  const char *p;
  size_t n;
  int c;

  if(!format || !tok || !tok[0]) return 0;
  n = strlen(tok);
  for(p = format; *p; ++p) {
    if((*p != '@' && *p != '%') || strncmp(p + 1, tok, n)) continue;
    c = (unsigned char)p[1 + n];
    if(!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '_')) return 1;
  }
  return 0;
}

/* GUARD UA-ELIDE, issue 0983. Copy <src> into <dest> as ONE line of at most
 * <max_chars> characters, marking a shortened result with "...".
 *
 * TWO MEASURED DEFECTS LIVE HERE and a reader would assume neither was
 * possible. (a) The sentence below is built into a fixed 2048-byte buffer, so
 * ONE instance attribute carrying a 1705-character value pushed the whole
 * recommended action off the end: the line stopped dead at "...give xLONG",
 * with nothing whatever to say it had been cut. (b) A value the user typed over
 * two physical lines -- shipped xschem_library/examples/tb_symbol_include.sch
 * writes its comm= value exactly that way -- put a newline INSIDE the sentence,
 * so the info window showed one warning as two entries and the second began
 * mid-word with "symbol reference to use in netlist, but SYMBOL_include never
 * reads comm...". Every variable-length field of the sentence goes through here,
 * so neither shape can come back whatever a user types on a sheet.
 *
 * <from_tail> keeps the END of the string rather than its beginning, and exists
 * for the sheet path: a path is identified by its last components, so a long one
 * must read ".../rom8k/rom2_predec1.sch" and never "/home/some/long/prefix...".
 *
 * Any run of whitespace -- spaces, tabs, newlines, carriage returns -- becomes a
 * single space, which is what makes (b) impossible rather than merely unlikely. */
static void unused_attr_elide(char *dest, size_t dest_size, const char *src,
                              size_t max_chars, int from_tail)
{
  const char *p;
  size_t flen = 0;
  size_t skip = 0;
  size_t seen = 0;
  size_t w = 0;
  int prev_space;
  int c;

  if(!dest || dest_size < 8) { if(dest && dest_size) dest[0] = '\0'; return; }
  dest[0] = '\0';
  if(!src || !src[0]) return;
  if(max_chars > dest_size - 4) max_chars = dest_size - 4;
  if(max_chars < 4) max_chars = 4;

  /* pass 1: how long the field becomes once every whitespace run is one space */
  prev_space = 0;
  for(p = src; *p; ++p) {
    c = (unsigned char)*p;
    if(c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      if(prev_space) continue;
      prev_space = 1;
    } else prev_space = 0;
    ++flen;
  }
  if(flen > max_chars && from_tail) {
    skip = flen - max_chars + 3;      /* +3: the "..." stands in for them */
    if(skip > flen) skip = flen;
    dest[w++] = '.'; dest[w++] = '.'; dest[w++] = '.';
  }

  prev_space = 0;
  for(p = src; *p; ++p) {
    c = (unsigned char)*p;
    if(c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      if(prev_space) continue;
      prev_space = 1;
      c = ' ';
    } else prev_space = 0;
    if(seen < skip) { ++seen; continue; }
    ++seen;
    if(w + 1 >= dest_size) break;
    if(!from_tail && w >= max_chars) {
      dest[w++] = '.'; dest[w++] = '.'; dest[w++] = '.';
      break;
    }
    dest[w++] = (char)c;
  }
  dest[w] = '\0';
}

/* GUARD UA-TMPL, issue 0980. Does the SYMBOL declare <tok> as one of the cell's
 * own settings -- that is, does the symbol's template= carry it?
 *
 * THIS IS THE FIX FOR THE WARNING THE PREVIOUS PASS SHIPPED, and a reader would
 * assume the question this diagnostic must answer is "does the format string
 * being written this minute mention it?". It is not. A symbol is netlisted in
 * six formats, and the VHDL and Verilog backends do not consult a format string
 * at all: print_vhdl_element() (this file, the TOK_END arm, `get_tok_value(
 * template, token, 0); if(xctx->tok_size)`) and print_verilog_element() (same
 * shape, plus an extra= exclusion) emit an instance attribute into the generic
 * or parameter map exactly when the SYMBOL's template= declares it. So a
 * setting the template declares does reach a netlist, even when the SPICE
 * format string never mentions it, and calling it dead is a lie.
 *
 * MEASURED, which is why this is a correction and not a refinement: before this
 * guard, netlisting the whole of xschem_library to SPICE printed 149 lines of
 * this kind on 18 sheets and 43 of them were false -- on SIX of those eighteen
 * sheets every single line was false. xschem_library/logic/ram_tb.sch was told
 * its datafile, dim, width, hex, modulename, access_delay and oe_delay "did not
 * reach the simulator and changed nothing", while the Verilog netlist of the
 * same sheet carries all seven into a module body that runs
 * $readmemh(datafile, mem) and `assign #access_delay iidata = idata;`.
 * xschem_library/examples/loading.sch was told the same about the capacitances,
 * conductances and delays its VHDL netlist writes as `cap => 30.0` and
 * `conduct => 1.0/20000.0`. A designer who followed that advice broke a working
 * shipped example, and the tool told them to.
 *
 * NOT generic_type=, which is the near miss: that attribute only picks quoting
 * and drops time-typed tokens from the Verilog map. Reading IT as the
 * consumption test silences 31 of the 43 and leaves ram_tb's datafile still
 * accused. Template membership is what separates 43 from 106 cleanly on the
 * shipped data.
 *
 * GUARD UA-EXTRA, deliberately inside this one: a name the symbol lists in
 * extra= is a NODE the cell gets wired to, not a setting the cell reads, so it
 * stays reportable even when the template also carries it. That is the seam
 * that keeps issue 0970's own case alive -- sky130_tests/passgate.sym declares
 * modelp in its template AND names it in extra=, and a designer who types
 * modelp= on one passgate still has to be told it went nowhere. Note the VHDL
 * backend disagrees with Verilog about extra= and writes such names into the
 * generic map; that asymmetry is filed as issue 0985 and is deliberately not
 * settled here. attr_is_extra_node() is hilight.c's, shared with
 * warn_hash_extra_node() above for the reason stated there. */
static int symbol_declares_param(int inst, const char *tok)
{
  const char *templ;
  const char *extra;
  int declared;

  if(!tok || !tok[0]) return 0;
  templ = (xctx->inst[inst].ptr + xctx->sym)->templ;
  if(!templ || !templ[0]) return 0;
  get_tok_value(templ, tok, 0);
  /* latch FIRST: the extra= lookup below overwrites xctx->tok_size */
  declared = xctx->tok_size ? 1 : 0;
  if(!declared) return 0;
  extra = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "extra", 0);
  if(attr_is_extra_node(extra, tok)) return 0;        /* GUARD UA-EXTRA */
  return 1;
}

/* GUARD UA-ALTFMT, issue 0987. Is <attr> -- one of the cell's alternate netlist
 * format strings -- there at all, and does it reference <tok>?
 *
 *   0 = the attribute is on neither the instance nor the symbol
 *   1 = it is there and does NOT reference tok
 *   2 = it is there and references tok
 *
 * THE INSTANCE IS ASKED FIRST AND WINS, because that is exactly what the
 * netlisters do: every one of them resolves a format attribute as instance
 * override, then symbol (print_spice_element, print_vhdl_element,
 * print_verilog_element, print_spectre_element, print_tedax_element all carry
 * the same four-step resolution). The previous version of this code OR'd the
 * two together, which is wrong twice over: an instance that brings its own
 * Spectre line is netlisted through THAT line and the symbol's is never parsed.
 * Row UF31 is the witness, and it is a separate row from UF25: deleting the
 * instance-side lookup altogether reddens UF25, but putting the OR back reddens
 * only UF31, because until that fixture no sheet anywhere carried an
 * instance-side format string that read a DIFFERENT token from the one the
 * symbol's reads, and OR and instance-wins give the same answer on every other.
 *
 * A READER WOULD ASSUME `1` IS JUST `0` WITH LESS INFORMATION. It is not, and
 * the difference is what issues 0987 and 0988 turn on: a backend that has a
 * format string of its own does NOT also emit the symbol template's parameters
 * -- print_vhdl_element and print_verilog_element both hand off to their
 * _primitive() form the moment fmt[0] is non-empty -- so `1` means "this
 * backend will not carry the setting either", and collapsing it into `0` would
 * put a format on the carrier list that carries nothing. That is a fabricated
 * claim about the user's own design, RULING D5-1.
 *
 * ISSUE 0992, AND IT IS THE WHOLE REASON THE PRESENCE TEST BELOW IS
 * xctx->tok_size ALONE. "Is the attribute there?" and "does it hold anything?"
 * are two different questions, and the netlisters ask only the first when they
 * decide whether to stop looking. print_vhdl_element and print_verilog_element
 * both read `get_tok_value(inst->prop_ptr, fmt_attr, 2); if(!xctx->tok_size)
 * <look at the symbol>` -- xctx->tok_size is the length of the token NAME that
 * matched, so an instance carrying vhdl_format="" IS the answer as far as they
 * are concerned and the symbol's own line is never read. They then find the
 * string empty, take the ordinary path, and write the cell's template
 * parameters after all.
 *
 * An earlier version of this function tested (xctx->tok_size && f && f[0]),
 * which reads as the same question and is not: an empty override on ONE COPY
 * of a cell made this code fall through to the SYMBOL's format string, which
 * the netlist being described never looks at. MEASURED, on a one-pin cell whose
 * template declares knob and whose symbol carries a VHDL line reading some
 * other token: the sheet types knob=99 and vhdl_format="" on one copy, the VHDL
 * netlist really does write `knob => 99` in that copy's generic map, and the
 * tool told the designer "uaemptf never reads knob when the netlist is written
 * ... or take it off". Following that advice deletes a live setting -- issue
 * 0980's harm, arriving through a new door. The mirror shape fabricated
 * instead: with the symbol's VHDL line reading knob and the template declaring
 * nothing, the tool named VHDL as a carrier while neither the VHDL nor the
 * Verilog netlist of that sheet mentioned knob anywhere, RULING D5-1.
 *
 * So: presence is tok_size, exactly as the netlisters have it, and an override
 * that IS there but empty resolves to state 0 -- no format string governs this
 * backend, the template path is the one taken -- which is what the netlisters
 * do one line later at `if(fmt[0])`. Rows UF33a and UF33b are the two shapes.
 *
 * get_tok_value() hands back a pointer into a static buffer that the NEXT call
 * overwrites, so the result is consumed before anything else is looked up. */
static int ua_fmt_attr_state(int inst, const char *attr, const char *tok)
{
  const char *f;
  int found;

  f = get_tok_value(xctx->inst[inst].prop_ptr, attr, 2);
  found = xctx->tok_size ? 1 : 0;
  if(!found) {
    f = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, attr, 2);
    found = xctx->tok_size ? 1 : 0;
  }
  if(!found || !f || !f[0]) return 0;
  return format_uses_token(f, tok) ? 2 : 1;
}

/* GUARD UA-IGNORE, issue 0988. Would this instance be written out AT ALL in the
 * netlist format these flag bits belong to?
 *
 * THIS IS THE CASE THE WHOLE DIAGNOSTIC EXISTS FOR AND IT WAS THE ONE THAT GOT
 * AWAY. A symbol or an instance may carry vhdl_ignore=true, verilog_ignore,
 * spectre_ignore or tedax_ignore, and then no netlist of that format contains
 * the instance at all -- so a setting its template happens to declare reaches
 * nothing, anywhere, and the accusing sentence is the truthful one. Before this
 * guard a template declaration alone silenced the warning, so a cell marked
 * un-netlistable in every other format was the quietest thing in the tree.
 * Measured on a fixture: the sheet types knob=99, the SPICE deck carries only
 * the template default knob=1, the VHDL netlist holds no instance of the cell
 * at all, and the tool said nothing.
 *
 * The bits are the ones skip_instance2() (netlist.c) tests, set from the
 * *_ignore attributes by set_sym_flags() and set_inst_flags() in actions.c, so
 * this asks the netlisters' own question. skip_instance2() itself cannot be
 * called here: it is static to netlist.c AND keyed to xctx->netlist_type, which
 * is SPICE at this call site, so it can only ever answer about SPICE. A
 * three-line reader of the same bits keeps this change to one file.
 *
 * LVS_IGNORE is deliberately NOT consulted. When it applies, spice_netlist.c's
 * own skip_instance() means print_spice_element() -- and so this whole check --
 * is never reached for that instance. */
static int ua_inst_or_sym_flag(int inst, int mask)
{
  return ((xctx->inst[inst].flags & mask) ||
          (xctx->sym[xctx->inst[inst].ptr].flags & mask)) ? 1 : 0;
}

/* GUARD UA-GENTIME, issue 0987. A generic the symbol types as `time` is dropped
 * from the Verilog instance parameter map -- print_verilog_element's
 * `strcmp(get_tok_value(generic_type, token, 0), "time")` test -- so Verilog
 * does not carry it even though the template declares it. A reader would assume
 * template membership settles both VHDL and Verilog together; on this one
 * attribute type it does not, and VHDL has no matching exclusion. Shipped
 * xschem_library/examples/loading.sch is the witness: switch_rreal.sym types
 * del as a time, so naming Verilog beside VHDL on those lines would name a
 * netlist that carries nothing -- RULING D5-1.
 *
 * generic_type= is read into a copy because the inner get_tok_value() overwrites
 * the static buffer the outer one just returned. */
static int ua_generic_is_time(int inst, const char *tok)
{
  char *gt = NULL;
  int r;

  my_strdup(_ALLOC_ID_, &gt,
            get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "generic_type", 0));
  if(!gt || !gt[0]) {
    my_free(_ALLOC_ID_, &gt);
    return 0;
  }
  r = !strcmp(get_tok_value(gt, tok, 0), "time");
  my_free(_ALLOC_ID_, &gt);
  return r;
}

/* GUARD UA-EMPTY, issue 0993. A setting with an EMPTY value is not written
 * into the generic/parameter map at all, and the two backends that walk the
 * template disagree about what "empty" means.
 *
 * A reader would assume template membership settles it -- the 0988 pass assumed
 * exactly that -- so here is the measurement, taken on the same one-pin cell
 * whose template declares knob, with the sheet typing knob="" on one copy: the
 * VHDL netlist writes `xEM : uatpl` with NO generic map, only the component's
 * own default, while the Verilog netlist writes `.knob ( "" )`. Naming VHDL
 * beside Verilog on that line would be a claim about the designer's own circuit
 * that nobody measured, RULING D5-1.
 *
 * WHY TWO MODES AND NOT ONE. Both netlisters end the value at `if(value[0] !=
 * '\0')`, but they build `value` differently: print_vhdl_element strips the
 * unescaped quotes as it parses (`if(c=='"' && !escape) quote=!quote; else
 * value[value_pos++]=c`), so "" leaves nothing behind, and
 * print_verilog_element keeps every character it sees, so "" is two characters
 * and counts. get_tok_value's bit 0 is that same difference -- 3 keeps quotes
 * and backslashes, 2 drops the unescaped ones -- and bit 1 is set in both so
 * that merely LOOKING at a value can never run a tcleval() hook.
 *
 * Shipped instances already carry attrs="", write="", sweep="", store="" and
 * nodeset=""; this needs only a cell whose template declares one of those
 * names. Row UF32 is the witness. */
#define UA_TMPL_NO      0   /* this backend never walks the symbol template */
#define UA_TMPL_DEQUOTE 1   /* VHDL: the parser strips "..." before the test */
#define UA_TMPL_RAW     2   /* Verilog: the parser keeps "..." so "" is a value */

static int ua_value_is_empty(int inst, const char *tok, int mode)
{
  const char *v;

  v = get_tok_value(xctx->inst[inst].prop_ptr, tok,
                    (mode == UA_TMPL_RAW) ? 3 : 2);
  return (!v || !v[0]) ? 1 : 0;
}

/* GUARD UA-FMTWINS, issues 0987 and 0988. Does the netlist format described by
 * <attr> and <mask> carry <tok> for THIS instance?
 *
 * <uses_template> is UA_TMPL_NO, UA_TMPL_DEQUOTE or UA_TMPL_RAW: whether that
 * backend emits the symbol template's parameters when it has no format string
 * of its own, and if it does, which spelling of "empty" it applies to the value
 * (GUARD UA-EMPTY above). VHDL and Verilog do; Spectre and tEDAx do NOT.
 *
 * A reader would assume all six formats behave alike
 * -- the 0980 pass assumed exactly that -- so here is the measurement, taken on
 * a one-pin subcircuit whose template declares knob and whose sheet sets
 * knob=99: the VHDL netlist writes `knob => 99`, the Verilog one writes
 * `.knob ( 99 )`, the Spectre product has no instance line for the cell at all
 * and the tEDAx one mentions knob nowhere. print_spectre_element() and
 * print_tedax_element() read spectre_format and tedax_format and nothing else;
 * neither falls back to `format` and neither walks the template. So template
 * membership is evidence for two backends and for no others.
 *
 * GUARD UA-FMTWINS is the `st == 1` line: a backend that has a format string of
 * its own is netlisted through that string and never through the parameter map,
 * so for that backend template membership counts for nothing. */
static int ua_backend_carries(int inst, const char *attr, int mask,
                              int uses_template, int drop_time, const char *tok)
{
  int st;

  if(ua_inst_or_sym_flag(inst, mask)) return 0;             /* GUARD UA-IGNORE */
  st = ua_fmt_attr_state(inst, attr, tok);
  if(st == 2) return 1;                                     /* GUARD UA-ALTFMT */
  if(st == 1) return 0;                                     /* GUARD UA-FMTWINS */
  if(uses_template == UA_TMPL_NO) return 0;
  if(drop_time && ua_generic_is_time(inst, tok)) return 0;   /* GUARD UA-GENTIME */
  if(ua_value_is_empty(inst, tok, uses_template)) return 0;   /* GUARD UA-EMPTY */
  return symbol_declares_param(inst, tok);      /* GUARD UA-TMPL + GUARD UA-EXTRA */
}

/* ISSUE 0987. How far does <tok> actually get? THREE answers, not two, and
 * <carriers> is filled in with the netlist formats measured for THIS instance.
 *
 *   UA_HERE      the deck being written right now reads it. Say nothing.
 *   UA_ELSEWHERE this deck drops it, but another netlist of the same cell
 *                really does carry it. Say so, and say DO NOT REMOVE IT.
 *   UA_NOWHERE   nothing anywhere reads it. The original 0970 sentence.
 *
 * A reader would assume UA_ELSEWHERE deserves silence -- the 0980 pass did, and
 * that is issue 0987: it turned 43 wrong accusations into 43 silences, one for
 * one, and shipped loading.sch's four capacitors went on simulating at the cell
 * default with nothing said.
 *
 * `spice_format` IS NOT IN THIS TABLE and its absence is deliberate. It is a
 * phantom: no backend reads it -- print_spice_element() resolves `format`, or
 * xctx->format when an LVS or custom-format run has set one -- and it is
 * declared by zero .sym files in xschem_library, sky130A, ihp-sg13g2, gf180mcuD
 * and xschem_libs_newsym. The 0980 pass silenced the warning on it, which was
 * silencing on nothing. It stays on the stoplist above, because a user may
 * still type the name.
 *
 * GUARD UA-CARRIERS, RULING D5-1: the sentence names the formats measured here,
 * joined as "VHDL or Verilog" or "Spectre, VHDL or Verilog", never a fixed
 * phrase. A hardcoded list would be a claim about the user's design that nobody
 * measured. */
#define UA_HERE      0
#define UA_ELSEWHERE 1
#define UA_NOWHERE   2

static int ua_reach(int inst, const char *format, const char *tok,
                    char *carriers, size_t csize)
{
  const char *names[4];
  const char *sep;
  size_t len;
  int n = 0;
  int i;

  /* Defensive, and deliberately invisible to any row -- the only caller resets
   * this itself one line before the call, and every path out of here that
   * returns UA_ELSEWHERE has written the join into it. It is here so that a
   * later caller cannot inherit the previous token's list. Deleting it changes
   * nothing a user sees, and no test row should be written to see it. */
  carriers[0] = '\0';
  if(format_uses_token(format, tok)) return UA_HERE;         /* GUARD UA-FMT */

  /* GUARD UA-LVSFMT, issue 0987. <format> is the string the deck is written
   * from, and in an LVS or custom-format run that is lvs_format, not `format`.
   * 110 files in this tree carry an lvs_format, so narrowing the first test to
   * the resolved string alone would newly call every setting only the ordinary
   * format line reads dead, and offer it for deletion -- issue 0980's harm
   * arriving through a new door.
   *
   * ⚠ THE `xctx->format &&` HALF IS A COST GUARD, NOT A CORRECTNESS ONE, and no
   * test row can see it or should try -- issue 0986's rule is about halves that
   * hide a defect. When xctx->format is NULL the resolved <format> above IS the
   * plain `format` attribute, resolved instance-then-symbol by exactly the same
   * four steps, so this second lookup would return the same answer the first
   * test already gave. Removing the condition changes no output; it only pays
   * two get_tok_value() calls per token per instance on every ordinary SPICE
   * netlist. Delete the whole line, though, and UF26 reddens. */
  if(xctx->format && ua_fmt_attr_state(inst, "format", tok) == 2) return UA_HERE;

  /* THE `| *_SHORT` HALF OF EACH MASK, issue 0991, and it is not decoration.
   * *_ignore takes THREE spellings, not two: `true`/`open` set the _IGNORE bit
   * and `short` sets the _SHORT bit (set_sym_flags and set_inst_flags in
   * actions.c). A cell or a copy marked `vhdl_ignore=short` is netlisted as a
   * plain WIRE joining its pins -- netlist.c's skip_instance(i, 1, ...) hands
   * skip_instance2 the _SHORT bit as well, so print_vhdl_element is never
   * reached for it -- and a wire carries no settings at all. Without this half
   * the sentence names a netlist in which the instance does not appear as an
   * instance, RULING D5-1. Rows UF30a-d take the four marks one at a time and
   * each demands the exact list that survives. */
  if(ua_backend_carries(inst, "spectre_format", SPECTRE_IGNORE | SPECTRE_SHORT,
                        UA_TMPL_NO, 0, tok)) names[n++] = "Spectre";
  if(ua_backend_carries(inst, "vhdl_format", VHDL_IGNORE | VHDL_SHORT,
                        UA_TMPL_DEQUOTE, 0, tok)) names[n++] = "VHDL";
  if(ua_backend_carries(inst, "verilog_format", VERILOG_IGNORE | VERILOG_SHORT,
                        UA_TMPL_RAW, 1, tok)) names[n++] = "Verilog";
  if(ua_backend_carries(inst, "tedax_format", TEDAX_IGNORE | TEDAX_SHORT,
                        UA_TMPL_NO, 0, tok)) names[n++] = "tEDAx";
  if(!n) return UA_NOWHERE;

  /* The join, and BOTH separators are load-bearing English. Two names read "VHDL
   * or Verilog"; three or four need the commas as well, "Spectre, VHDL, Verilog
   * or tEDAx". Until row UF29 there was no sheet anywhere -- shipped or fixture
   * -- that produced more than two carriers, so the ", " branch was executed by
   * nothing and "a VHDL, Verilog netlist" or "a VHDLVerilog netlist" could have
   * shipped past every check, against the PLAIN ENGLISH ruling. UF29 demands
   * the joined phrase verbatim, not the set of names.
   *
   * The length test is the same shape as GUARD UA-ELIDE's destination clamp and
   * is unreachable for the same reason: four names at most, the longest join is
   * "Spectre, VHDL, Verilog or tEDAx" at 31 characters, and the only caller
   * hands in a 64-byte buffer. No sentence a user can produce reaches it, so row
   * UF22 pins it structurally rather than trading a field the reader needs for a
   * test -- issue 0986 gap 5, same argument. */
  len = 0;
  for(i = 0; i < n; ++i) {
    sep = "";
    if(i > 0) sep = (i == n - 1) ? " or " : ", ";
    if(len + strlen(sep) + strlen(names[i]) + 1 >= csize) break;
    strcpy(carriers + len, sep);
    len += strlen(sep);
    strcpy(carriers + len, names[i]);
    len += strlen(names[i]);
  }
  return UA_ELSEWHERE;
}

/* GUARD UA-SYMNAME, issue 0980. Does the instance's own SYMBOL REFERENCE read
 * the setting?
 *
 * A reader would assume the cell an instance points at is a fixed name somebody
 * typed on the sheet. It is not. xschem substitutes the instance's attributes
 * into the symbol reference before resolving it -- link_symbols_to_instances()
 * in save.c calls translate() on xctx->inst[].name -- and the shipped library
 * uses that on purpose. xschem_library/generators/test_symbolgen.sch places
 * `symbolgen.tcl(inv,@ROUT\)` and sets ROUT=1200 on it, and the SPICE deck
 * really does get `x1 IN_INV IN symbolgen_tcl_inv_1200`. The setting chose the
 * cell body: it is the loudest way a setting can possibly reach the simulator,
 * and the first version of this diagnostic told the user on six shipped lines
 * that it had changed nothing and they should take it off. Doing so would point
 * the sheet at symbolgen_tcl_inv_ , a different cell that is not there.
 *
 * xctx->inst[].name is the RAW reference, with the @ still in it; the resolved
 * name lives on the symbol, so this is the only place the question can be
 * asked. The tree ships two more of this shape, mosgen.tcl(@model\) and
 * tier.tcl(@lab\), both under xschem_library/generators/. Whole-token test, for
 * the reason GUARD UA-FMT states. */
static int symbol_name_uses_token(int inst, const char *tok)
{
  return format_uses_token(xctx->inst[inst].name, tok);
}

/* ISSUE 0970: say so, once per lost setting, in words a designer reads as
 * "you typed this and it had no effect".
 *
 * Called once per instance from print_spice_element(), after the format string
 * has been resolved and before it is parsed, so the four-way resolution above
 * (instance override, symbol, then the same two again for a per-format
 * attribute) has already decided WHICH format string this instance is netlisted
 * through -- the check must ask about that one, not about the symbol's.
 *
 * SEVERITY IS DELIBERATE: statusmsg(str, 2) appends to the info/ERC window's
 * text and does NOT raise the netlister's error flag, so it reads exactly like
 * the existing open-net and '#'-node notices and does not force the info window
 * open (show_infowindow_after_netlist defaults to `onerror`). A discarded
 * setting is worth telling the user about; it is not worth interrupting every
 * netlist of a design that has one. That loudness is on the user's ruling queue
 * with issue 0970. */
static void warn_unused_instance_attr(int inst, const char *format)
{
  const char *type;
  const char *prop;
  const char *val;
  const char *sym_cell;
  const char *instname;
  const char *sheet;
  char *toks = NULL;
  char *p;
  char *q;
  char str[2048];
  char e_sheet[160];
  char e_inst[80];
  char e_cell[80];
  char e_prop[80];
  char e_val[160];
  /* ISSUE 0987: the two clauses that differ between the two shapes of the
   * sentence. They are separate buffers so that RULING D5-4 stays true -- the
   * sentence itself is still built by ONE my_snprintf into str, and handed to
   * the info window exactly once, whichever shape it took. */
  char mid[240];
  char advice[640];
  char carriers[64];
  size_t saved_tok_size;
  int i;
  int skip;
  int reach;

  if(!format || !format[0]) return;
  if(inst < 0 || xctx->inst[inst].ptr < 0) return;
  prop = xctx->inst[inst].prop_ptr;
  if(!prop || !prop[0]) return;

  /* GUARD UA-TYPE, issue 0970. Only cells whose insides are written out ONCE
   * from a template. That is what this whole class IS: a per-copy setting has
   * nowhere to go precisely because there is only one body. A reader would
   * assume the check is about "unused attributes" in general -- it is not, and
   * measured without this guard the rule emits 6863 lines across the two
   * shipped PDK trees instead of 10. A transistor placed straight on a sheet
   * gets its own line in the deck and is nobody's problem here. */
  type = (xctx->inst[inst].ptr + xctx->sym)->type;
  if(!type || strcmp(type, "subcircuit")) return;

  /* get_tok_value() overwrites xctx->tok_size, which print_spice_element() uses
   * as its "token ABSENT" signal while resolving the format string. Latch it and
   * put it back, exactly as warn_hash_extra_node() does and for the same stated
   * reason: an observer may never become the reason a real netlist value goes
   * missing if this call site ever moves. GUARD UA-TOKSIZE -- invisible at
   * today's call site, which is why only a structural test row can see it. */
  saved_tok_size = xctx->tok_size;

  /* GUARD UA-POLY, issue 0970. An instance carrying `schematic=` (or one of the
   * *_sym_def bodies) gets a symbol block of its OWN from
   * get_additional_symbols(), whose parent property string is this instance's,
   * so `model=@modelp` inside the cell resolves to what THIS copy asked for and
   * the deck really does get a second body. Accusing it of having typed
   * something that changed nothing would be exactly backwards -- and after this
   * pass's own repair of the bandgap bench, whose two passgates now carry
   * `schematic=passgate_lvtp`, this guard is the only thing standing between
   * the user and being told their working override did nothing. Measured: 6 of
   * sky130A's 10 remaining hits are this shape. */
  get_tok_value(prop, "schematic", 0);
  skip = xctx->tok_size ? 1 : 0;
  if(!skip) { get_tok_value(prop, "spice_sym_def", 0);   skip = xctx->tok_size ? 1 : 0; }
  if(!skip) { get_tok_value(prop, "spectre_sym_def", 0); skip = xctx->tok_size ? 1 : 0; }
  if(!skip) { get_tok_value(prop, "vhdl_sym_def", 0);    skip = xctx->tok_size ? 1 : 0; }
  if(!skip) { get_tok_value(prop, "verilog_sym_def", 0); skip = xctx->tok_size ? 1 : 0; }
  if(!skip) { get_tok_value(prop, "tedax_sym_def", 0);   skip = xctx->tok_size ? 1 : 0; }
  if(skip) {
    xctx->tok_size = saved_tok_size;
    return;
  }

  instname = xctx->inst[inst].instname ? xctx->inst[inst].instname : "?";
  sym_cell = get_cell((xctx->inst[inst].ptr + xctx->sym)->name, 0);

  /* GUARD UA-SHEET, issue 0981. Which sheet is this instance actually ON?
   *
   * The sentence used to open "on this sheet", and a reader would assume that
   * is true because the netlister is writing the sheet the user opened. It is
   * not: the netlister descends, and print_spice_element() runs once per
   * instance of every sub-cell too. Measured on the shipped ROM,
   * xschem_library/rom8k/rom8k.sch, which contains not one lvnand2: netlisting
   * it printed 23 paragraphs saying "on this sheet, instance x2 (a lvnand2)",
   * 10 distinct, with four instance names each printed three times
   * byte-identically -- three DIFFERENT x2s, on rom2_predec1.sch,
   * rom2_predec3.sch and rom2_predec4.sch, that the user could not tell apart.
   *
   * xctx->current_name is right at this moment because spice_block_netlist()
   * calls load_schematic() (save.c, which sets it) before spice_netlist() walks
   * the sub-cell's instances, and global_spice_netlist() puts the top sheet's
   * name back on the way out (spice_netlist.c). The two fallbacks are for a
   * caller that never went through either. */
  sheet = (xctx->current_name[0]) ? xctx->current_name :
          (xctx->sch[xctx->currsch] ? xctx->sch[xctx->currsch] : "?");

  /* GUARD UA-INST, issue 0970. The tokens come from the INSTANCE's own property
   * string, never from the symbol template. "You typed this and it had no
   * effect" is a claim about what the user wrote on the sheet; a template
   * default the format does not read is the symbol author's business and not a
   * lost setting, so it must never be reported. list_tokens() returns a static
   * buffer, hence the copy. */
  my_strdup(_ALLOC_ID_, &toks, list_tokens(prop, 0));
  p = toks;
  while(p && *p) {
    while(*p == ' ' || *p == '\t' || *p == '\n') ++p;
    if(!*p) break;
    q = p;
    while(*q && *q != ' ' && *q != '\t' && *q != '\n') ++q;
    if(*q) { *q = '\0'; ++q; }

    skip = 0;
    /* Defensive, and deliberately invisible to any row: reach is assigned by
     * ua_reach() on every path that can reach the print block below, so this
     * reset cannot change what the user sees. It is here so that a later hand
     * adding a test between the two cannot inherit the previous token's answer. */
    reach = UA_NOWHERE;
    carriers[0] = '\0';
    /* GUARD UA-NAME, issue 0970. A token that does not read as an attribute
     * NAME is not a setting the user typed, and the tree really contains such
     * tokens: the shipped sky130_tests/charge_pump_phasegen sheet writes its
     * instance properties over three lines with SPICE-style '+' continuation
     * markers, so list_tokens() hands back a bare "+" twice per instance.
     * Measured: without this guard the shipped tb_charge_pump bench emits 8
     * lines reading `instance x7 (a lvtnot) sets +=`, which is nonsense to a
     * reader and would have been the whole of this diagnostic's noise budget.
     * An attribute name starts with a letter or an underscore. */
    if(!((p[0] >= 'a' && p[0] <= 'z') || (p[0] >= 'A' && p[0] <= 'Z') ||
         p[0] == '_')) skip = 1;
    /* GUARD UA-STOP: the measured exemptions, above. */
    for(i = 0; !skip && unused_attr_stoplist[i]; ++i) {
      if(!strcmp(p, unused_attr_stoplist[i])) { skip = 1; break; }
    }
    /* GUARD UA-POLY's own tokens: an instance carrying one of these never gets
     * here, but naming them keeps a reader from adding them to the stoplist and
     * quietly turning the skip-the-whole-instance rule into a skip-one-attribute
     * rule. */
    if(!skip && (!strcmp(p, "schematic") || !strcmp(p, "spice_sym_def") ||
                 !strcmp(p, "spectre_sym_def") || !strcmp(p, "vhdl_sym_def") ||
                 !strcmp(p, "verilog_sym_def") || !strcmp(p, "tedax_sym_def"))) skip = 1;
    /* GUARD UA-STOP2, issue 0989: a name the EDITOR reads for itself is excused
     * only while the cell does not declare it as one of its own parameters. The
     * list above is consulted by name alone; this one asks about the cell, which
     * is why a subcircuit parameter a designer called `select` can be reported
     * at last while the shipped solar panel's editing convenience is untouched. */
    for(i = 0; !skip && unused_attr_cellparam_stoplist[i]; ++i) {
      if(!strcmp(p, unused_attr_cellparam_stoplist[i]) &&
         !symbol_declares_param(inst, p)) { skip = 1; break; }
    }
    /* GUARD UA-SYMNAME, issue 0980: a setting the instance's symbol reference
     * substitutes into the cell name picks WHICH cell body is written out. It
     * stays the FIRST of the reach tests: it is the loudest way a setting can
     * reach the simulator, so there is nothing to report about it in any shape. */
    if(!skip && symbol_name_uses_token(inst, p)) skip = 1;
    /* ISSUE 0987: and then how far it gets -- this deck, some other netlist of
     * the same cell, or nothing anywhere. Only the first of those is silent. */
    if(!skip) {
      reach = ua_reach(inst, format, p, carriers, S(carriers));
      if(reach == UA_HERE) skip = 1;
    }
    if(!skip) {
      val = get_tok_value(prop, p, 0);
      /* GUARD UA-ELIDE, issue 0983: every variable-length field is shortened to
       * one line of bounded length BEFORE the sentence is built, so no value a
       * user types can cost the reader the recommended action or split the
       * warning across two info-window entries. */
      unused_attr_elide(e_sheet, S(e_sheet), sheet, 120, 1);
      unused_attr_elide(e_inst,  S(e_inst),  instname, 60, 0);
      unused_attr_elide(e_cell,  S(e_cell),  sym_cell, 60, 0);
      unused_attr_elide(e_prop,  S(e_prop),  p, 60, 0);
      unused_attr_elide(e_val,   S(e_val),   val ? val : "", 120, 0);
      /* ISSUES 0987 AND 0988, THE TWO SHAPES. They differ in the clause that
       * says WHY the setting was lost and in the action they ask for, and those
       * actions are opposites -- take it off, versus do not take it off. Both
       * keep the contract phrase "did not reach the simulator" verbatim, which
       * is how the test suite recognises the whole class, and both open the
       * same way, so a reader who has seen one recognises the other.
       *
       * THE SECOND SHAPE MUST NEVER TELL THE USER TO DELETE ANYTHING. That one
       * clause is the whole of issue 0980's harm: following it on shipped
       * xschem_library/examples/loading.sch or logic/ram_tb.sch breaks a working
       * example, because the VHDL and Verilog netlists of those very sheets
       * carry the settings the SPICE deck drops. So neither half of the accusing
       * advice appears below in the UA_ELSEWHERE arm, and a test row asserts
       * their absence from every line of that shape the whole run produces.
       *
       * ISSUE 0982, the accusing advice: the old wording told the user to "give
       * x1 a schematic= attribute of its own", which walks them into a silent
       * collision. Measured on two copies of one cell given the SAME name, as
       * that sentence invites: the deck holds ONE cell body carrying the first
       * instance's setting, the second instance's setting appears nowhere at
       * all, and the netlister says nothing about it -- GUARD UA-POLY above has
       * already skipped both instances, so the very diagnostic that exists to
       * catch "your setting reached nothing" is structurally blind to the state
       * its own advice created. The advice now names the requirement and says
       * what breaks without it. Detecting the collision itself is issue 0982's
       * remaining half and is not done here. */
      if(reach == UA_ELSEWHERE) {
        my_snprintf(mid, S(mid),
          "a SPICE netlist of %s does not pass %s through", e_cell, e_prop);
        my_snprintf(advice, S(advice),
          "It is not a spelling mistake and you should not remove it: a %s "
          "netlist of the same cell does carry it, so deleting it would break "
          "that. To get it into the SPICE run as well, the %s symbol has to be "
          "changed so its SPICE line passes it through.", carriers, e_cell);
      } else {
        my_snprintf(mid, S(mid),
          "%s never reads %s when the netlist is written", e_cell, e_prop);
        my_snprintf(advice, S(advice),
          "Check the spelling against the settings this cell does read, or take "
          "it off. If you meant to change only this one copy of the cell, add a "
          "schematic= attribute to %s naming a cell name that no other instance "
          "asks for, and that copy is written out on its own with your setting "
          "in it. Two instances that ask for the same name quietly share one "
          "copy, and only the first one's setting is kept.", e_inst);
      }
      /* RULING D5-4: whichever shape it took, the sentence is assembled HERE and
       * nowhere else, and handed to the info window exactly once. */
      my_snprintf(str, S(str),
        "Warning: on sheet %s, instance %s (a %s) sets %s=%s, but %s, so that "
        "setting did not reach the simulator and changed nothing. %s",
        e_sheet, e_inst, e_cell, e_prop, e_val, mid, advice);
      statusmsg(str, 2);
    }
    p = q;
  }
  my_free(_ALLOC_ID_, &toks);
  xctx->tok_size = saved_tok_size;
}

int print_spice_element(FILE *fd, int inst)
{
  int i=0, multip, itmp;
  const char *str_ptr=NULL;
  register int c, state=TOK_BEGIN, space;
  char *template=NULL,*format=NULL, *s, *name=NULL,  *token=NULL;
  const char *lab;
  const char *value = NULL;
  /* char *translatedvalue = NULL; */
  size_t sizetok=0;
  size_t token_pos=0;
  int escape=0;
  int no_of_pins=0;
  char *result = NULL;
  size_t size = 0;
  char *spiceprefixtag = NULL;
  const char *fmt_attr = NULL;

  size = CADCHUNKALLOC;
  my_realloc(_ALLOC_ID_, &result, size);
  result[0] = '\0';

  my_strdup(_ALLOC_ID_, &template, (xctx->inst[inst].ptr + xctx->sym)->templ);
  my_strdup(_ALLOC_ID_, &name,xctx->inst[inst].instname);
  if (!name) my_strdup(_ALLOC_ID_, &name, get_tok_value(template, "name", 0));

  fmt_attr = xctx->format ? xctx->format : "format";
  /* allow format string override in instance */
  my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr, fmt_attr, 2));
  /* get netlist format rule from symbol */
  if(!xctx->tok_size)
    my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, fmt_attr, 2));
  /* allow format string override in instance */
  if(!xctx->tok_size && strcmp(fmt_attr, "format") )
    my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr, "format", 2));
  /* get netlist format rule from symbol */
  if(!xctx->tok_size && strcmp(fmt_attr, "format"))
     my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "format", 2));
  if ((name==NULL) || (format==NULL)) {
    my_free(_ALLOC_ID_, &template);
    my_free(_ALLOC_ID_, &format);
    my_free(_ALLOC_ID_, &name);
    my_free(_ALLOC_ID_, &result);
    return 0; /* do no netlist unwanted insts(no format) */
  }
  /* ISSUE 0970: here, and only here. The four-way resolution above has just
   * settled WHICH format string this instance is netlisted through, and the
   * parse loop below has not started consuming it yet, so this is the one point
   * where the question "does this instance set anything the deck will never
   * see?" can be asked against the string the deck is actually written from. */
  warn_unused_instance_attr(inst, format);
  no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
  s=format;
  dbg(1, "print_spice_element(): name=%s, format=%s xctx->netlist_count=%d\n",name,format, xctx->netlist_count);
  /* begin parsing format string */
  while(1)
  {
    /* always make room for some characters so the single char writes to result do not need reallocs */
    c=*s++;
    if(c=='\\') {
      escape=1;
      c=*s++;
    }
    else escape=0;

    if (c=='\n' && escape) c=*s++; /* 20171030 eat escaped newlines */
    space=SPACE(c);
    if ( state==TOK_BEGIN && (c=='@'|| c=='%')  && !escape ) state=TOK_TOKEN;
    else if(state==TOK_TOKEN && token_pos > 1 &&
       (
         ( (space  || c == '%' || c == '@') && !escape ) ||
         ( (!space && c != '%' && c != '@') && escape  )
       )
      ) {
      dbg(1, "print_spice_element(): c=%c, space=%d, escape=%d token_pos=%d\n", c, space, escape, token_pos);
      state=TOK_SEP;
    }
    STR_ALLOC(&token, token_pos, &sizetok);
    if(state==TOK_TOKEN) {
      token[token_pos++]=(char)c;
    }
    else if (state==TOK_SEP)                    /* got a token */
    {
      char *val = NULL;
      size_t token_exists = 0;
      token[token_pos]='\0';
      token_pos=0;

      if(strcmp(token,"@symref")==0)
      {
        const char *s = get_sym_name(inst, 9999, 1, 0);
        my_mstrcat(_ALLOC_ID_, &result, s, NULL);
      }
      else if (strcmp(token,"@symname")==0) /* of course symname must not be present in attributes */
      {
        const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 0, 0)));
        my_mstrcat(_ALLOC_ID_, &result, s, NULL);
      }
      else if (strcmp(token,"@symname_ext")==0) /* of course symname_ext must not be present in attributes */
      {
        const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 1, 0)));
        my_mstrcat(_ALLOC_ID_, &result, s, NULL);
      }
      else if(strcmp(token,"@topschname")==0) /* of course topschname must not be present in attributes */
      {
        const char *topsch;
        topsch = get_trailing_path(xctx->sch[0], 0, 1);
        my_mstrcat(_ALLOC_ID_, &result, topsch, NULL);
      }
      else if(strcmp(token,"@schname_ext")==0) /* of course schname must not be present in attributes */
      {
        my_mstrcat(_ALLOC_ID_, &result, xctx->current_name, NULL);
      }
      else if(strcmp(token,"@savecurrent")==0)
      {
        char *instname = xctx->inst[inst].instname;

        const char *sc = get_tok_value(xctx->inst[inst].prop_ptr, "savecurrent", 0);
        if(!sc[0]) sc = get_tok_value(template, "savecurrent", 0);
        if(!strboolcmp(sc , "true")) {
          my_mstrcat(_ALLOC_ID_, &result, "\n.save I( ?1 ", instname, " )", NULL);
        }
      }
      else if(strcmp(token,"@schname")==0) /* of course schname must not be present in attributes */
      {
        const char *schname = get_cell(xctx->current_name, 0);
        my_mstrcat(_ALLOC_ID_, &result, schname, NULL);
      }
      else if(strcmp(token,"@pinlist")==0) /* of course pinlist must not be present in attributes */
                                           /* print multiplicity */
      {                                    /* and node number: m1 n1 m2 n2 .... */
        if(!has_included_subcircuit(inst, xctx->inst[inst].ptr, &result)) {
          Int_hashtable table = {NULL, 0};
          int_hash_init(&table, 37);
          for(i=0;i<no_of_pins; ++i)
          {
            char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][i].prop_ptr;
            int spice_ignore = !strboolcmp(get_tok_value(prop, "spice_ignore", 0), "true");
            const char *name = get_tok_value(prop, "name", 0);
            if(!spice_ignore) {
              if(!int_hash_lookup(&table, name, 1, XINSERT_NOREPLACE)) {
                str_ptr =  net_name(inst, i, &multip, 0, 1);

                my_mstrcat(_ALLOC_ID_, &result, "?", my_itoa(multip), " ", str_ptr, " ", NULL);
              }
            }
          }
          int_hash_free(&table);
        }
      }
      else if(token[0]=='@' && token[1]=='@') {    /* recognize single pins 15112003 */
        for(i=0;i<no_of_pins; ++i) {
          char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][i].prop_ptr;
          if (!strcmp( get_tok_value(prop,"name",0), token+2)) {
            if(strboolcmp(get_tok_value(prop,"spice_ignore",0), "true")) {
              str_ptr =  net_name(inst,i, &multip, 0, 1);

              my_mstrcat(_ALLOC_ID_, &result, "?", my_itoa(multip), " ", str_ptr, " ", NULL);
            }
            break;
          }
        }
      }
      /* reference by pin number instead of pin name, allows faster lookup of the attached net name
       * @#0, @#1:net_name, @#2:name, ... */
      else if(token[0]=='@' && token[1]=='#') {
        int n;
        char *pin_attr = NULL;
        char *pin_num_or_name = NULL;

        get_pin_and_attr(token, &pin_num_or_name, &pin_attr);
        n = get_inst_pin_number(inst, pin_num_or_name);
        if(n>=0  && pin_attr[0] && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
          char *pin_attr_value = NULL;
          int is_net_name = !strcmp(pin_attr, "net_name");
          /* get pin_attr value from instance: "pinnumber(ENABLE)=5" --> return 5, attr "pinnumber" of pin "ENABLE"
           *                                   "pinnumber(3)=6       --> return 6, attr "pinnumber" of 4th pin */
          if(!is_net_name) {
            pin_attr_value = get_pin_attr_from_inst(inst, n, pin_attr);
            /* get pin_attr from instance pin attribute string */
            if(!pin_attr_value) {
             my_strdup(_ALLOC_ID_, &pin_attr_value,
                get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][n].prop_ptr, pin_attr, 0));
            }
          }
          /* @#n:net_name attribute (n = pin number or name) will translate to net name attached  to pin */
          if(!pin_attr_value && is_net_name) {
            prepare_netlist_structs(0);
            my_strdup(_ALLOC_ID_, &pin_attr_value,
                 xctx->inst[inst].node && xctx->inst[inst].node[n] ? xctx->inst[inst].node[n] : "?");
          }
          if(!pin_attr_value ) my_strdup(_ALLOC_ID_, &pin_attr_value, "--UNDEF--");
          value = pin_attr_value;
          /* recognize slotted devices: instname = "U3:3", value = "a:b:c:d" --> value = "c" */
          if(value[0] && !strcmp(pin_attr, "pinnumber") ) {
            char *ss;
            int slot;
            char *tmpstr = NULL;
            tmpstr = my_malloc(_ALLOC_ID_, sizeof(xctx->inst[inst].instname));
            if( (ss=strchr(xctx->inst[inst].instname, ':')) ) {
              sscanf(ss+1, "%s", tmpstr);
              if(isonlydigit(tmpstr)) {
                slot = atoi(tmpstr);
                if(strstr(value,":")) value = find_nth(value, ":", "", 0, slot);
              }
            }
            my_free(_ALLOC_ID_, &tmpstr);
          }
          my_mstrcat(_ALLOC_ID_, &result, value, NULL);
          my_free(_ALLOC_ID_, &pin_attr_value);
        }
        else if(n>=0  && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
          const char *si;
          char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][n].prop_ptr;
          si  = get_tok_value(prop, "spice_ignore",0);
          if(strboolcmp(si, "true")) {
            str_ptr =  net_name(inst,n, &multip, 0, 1);

            my_mstrcat(_ALLOC_ID_, &result, "?", my_itoa(multip), " ", str_ptr, " ", NULL);
          }
        }
        my_free(_ALLOC_ID_, &pin_attr);
        my_free(_ALLOC_ID_, &pin_num_or_name);
      }
      else if (!strncmp(token,"@tcleval", 8)) {
        size_t s;
        char *tclcmd=NULL;
        const char *res;
        s = token_pos + strlen(name) + strlen(xctx->inst[inst].name) + 100;
        tclcmd = my_malloc(_ALLOC_ID_, s);
        Tcl_ResetResult(interp);
        my_snprintf(tclcmd, s, "tclpropeval {%s} {%s} {%s}", token, name, xctx->inst[inst].name);
        dbg(1, "print_spice_element(): tclpropeval {%s} {%s} {%s}", token, name, xctx->inst[inst].name);
        res = tcleval(tclcmd);

        my_mstrcat(_ALLOC_ID_, &result, res, NULL);
        my_free(_ALLOC_ID_, &tclcmd);
      }
      /* if spiceprefix==0 and token == @spiceprefix then set empty value */
      else if (!tclgetboolvar("spiceprefix") && !strcmp(token, "@spiceprefix")) {
        value=NULL;
      /* else tcl var spiceprefix is enabled  */
      }

      else {
        /* here a @token in format string will be replaced by value in instance prop_ptr
         * or symbol template */
        size_t tok_val_len;
        char *parent_prop_ptr = NULL;
        char *parent_templ = NULL;
        char *schname_attr = NULL;
        my_mstrcat(_ALLOC_ID_, &schname_attr, "schname=\"", get_cell(xctx->current_name, 0), "\"", NULL);

        if(xctx->currsch > 0) {
          parent_prop_ptr = xctx->hier_attr[xctx->currsch - 1].prop_ptr;
          parent_templ = xctx->hier_attr[xctx->currsch - 1].templ;
        }

        /* consider this scenario:
         * instance of passgate.sym: W_N=5 L_N=0.2 W_P=10 L_P=0.3 m=1
         * instance based schematic (schematic=mypippo attr) will have also modeln=pippon
         *    passgate.sym:
         *      format="@name @pinlist @symname W_N=@W_N L_N=@L_N W_P=@W_P L_P=@L_P m=@m"
         *      template=" ... modeln=nfet_01v8 modelp=pfet_01v8 m=1"
         *    passgate.sch:
         *       instance of nmos.sym: L=L_N W=W_N nf=1 m=1 model=@modeln
         *         nmos.sym:
         *           format="@name @pinlist @model L=@L W=@W nf=@nf
         *           + ad=@ad as=@as pd=@pd .... m=@m
         *           template="name=M1 W=1 L=0.15 m=1
         *             ad=\"expr('int((@nf + 1)/2) * @W / @nf * 0.29')\"
         *             ..."
         *           model=nfet_01v8
         */

        my_strdup2(_ALLOC_ID_, &val,
             translate3(token, 0, xctx->inst[inst].prop_ptr, NULL, NULL, NULL));
        /* can not put template in above translate3: ---------------------------^^^^
         * if instance has VHI=VHI, format string has VHI=@VHI, and symbol template has VHI=3
         * we do not want token @VHI to resolve to 3, but stop at VHI as specified in instance */
        if(strchr(val, '@')) {
           my_strdup2(_ALLOC_ID_, &val,
              translate3(val, 0, xctx->inst[inst].prop_ptr, parent_prop_ptr, template, NULL));
        }
        /* nmos instance format string: @model --> @modeln */
        dbg(1, "print_spice_element(): 1st round: val: |%s|\n", val);
        if(strchr(val, '@')) {
            my_strdup2(_ALLOC_ID_, &val,
                   translate3(val, 1, schname_attr, xctx->inst[inst].prop_ptr, NULL, NULL));
            /*                        ............ --> replace @symname with symbol name */
            dbg(1, "print_spice_element(): 2nd round: val: |%s|\n", val);
            /* normal passgate.sym placement, nmos instance format string:
                 ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')" --> ad="expr('int((1 + 1)/2) * W_N/ 1 * 0.29')" */
            if(strchr(val, '@')) {
              my_strdup2(_ALLOC_ID_, &val,
                     translate3(val, 0, xctx->inst[inst].prop_ptr, parent_templ, NULL, NULL));
              dbg(1, "print_spice_element(): 3nd round: val: |%s|\n", val);
              /* normal passgate.sym placement, nmos instance format string:
               *   @modeln --> nfet_01v8 */
            }
          dbg(1, "print_spice_element(): final: val: |%s|\n", val);
        }
        my_free(_ALLOC_ID_, &schname_attr);
        /* still unresolved: set to empty */
        if(val[0] == '@') value = "";
        else value = val;
        token_exists = xctx->tok_size;
        tok_val_len = strlen(value);
        /* @spiceprefix needs a special tag for postprocessing */
        if(!strcmp(token, "@spiceprefix") && value[0]) {
          my_realloc(_ALLOC_ID_, &spiceprefixtag, tok_val_len+22);
          my_snprintf(spiceprefixtag, tok_val_len+22, "**** spice_prefix %s\n", value);
          value = spiceprefixtag;
        }

        if(is_expr(value)) {
          value =  eval_expr(value);
        }
        warn_hash_extra_node(inst, token + 1, value);   /* ERC, issue 0165 */
        /* token=%xxxx and xxxx is not defined in prop_ptr or template: return xxxx */
        if(!token_exists && token[0] =='%') {
          my_mstrcat(_ALLOC_ID_, &result, token + 1, NULL);
        }
        /* And finally set the value of token into result string */
        else if (value && value[0]!='\0') {
           /* instance names (name) and node labels (lab) go thru the expandlabel function. */
          /*if something else must be parsed, put an if here! */
          if (!(strcmp(token+1,"name") && strcmp(token+1,"lab"))  /* expand name/labels */
                && ((lab = expandlabel(value, &itmp)) != NULL)) {
            my_mstrcat(_ALLOC_ID_, &result, lab, NULL);
          } else {
            my_mstrcat(_ALLOC_ID_, &result, value, NULL);
          }
        }
      } /* else */

      /* append token separator to output result ... */
      if(c != '%' && c != '@' && c!='\0' ) {
        char str[2];
        str[0] = (unsigned char) c;
        str[1] = '\0';
        my_mstrcat(_ALLOC_ID_, &result, str, NULL);
      }
      /* ... unless it is the start of another token, so push back to input string */
      if(c == '@' || c == '%' ) s--;
      state=TOK_BEGIN;
      my_free(_ALLOC_ID_, &val);
    } /* else if (state==TOK_SEP) */

    else if(state==TOK_BEGIN && c!='\0') {
      char str[2];
      str[0] = (unsigned char) c;
      str[1] = '\0';
      my_mstrcat(_ALLOC_ID_, &result, str, NULL);
    }
    if(c=='\0')
    {
      char str[2];
      str[0] = '\n';
      str[1] = '\0';
      my_mstrcat(_ALLOC_ID_, &result, str, NULL);
      break;
    }
  } /* while(1) */


  /* if result is like: 'tcleval(some_string)' pass it thru tcl evaluation so expressions
   * can be calculated */
  if(result) {
     my_strdup(_ALLOC_ID_, &result, tcl_hook2(result));
  }
  if(is_expr(result)) {
    my_strdup2(_ALLOC_ID_, &result, eval_expr(result));
  }
  if(result) fprintf(fd, "%s", result);
  dbg(1, "print_spice_element(): returning |%s|\n", result);
  my_free(_ALLOC_ID_, &template);
  my_free(_ALLOC_ID_, &format);
  my_free(_ALLOC_ID_, &name);
  my_free(_ALLOC_ID_, &token);
  my_free(_ALLOC_ID_, &result);
  if(spiceprefixtag) my_free(_ALLOC_ID_, &spiceprefixtag);
  /* my_free(_ALLOC_ID_, &translatedvalue); */
  return 1;
}

int print_spectre_element(FILE *fd, int inst)
{
  int i=0, multip, itmp;
  const char *str_ptr=NULL;
  register int c, state=TOK_BEGIN, space;
  char *template=NULL,*format=NULL, *s, *name=NULL,  *token=NULL;
  const char *lab;
  const char *value = NULL;
  /* char *translatedvalue = NULL; */
  size_t sizetok=0;
  size_t token_pos=0;
  int escape=0;
  int no_of_pins=0;
  char *result = NULL;
  size_t size = 0;
  char *spiceprefixtag = NULL;
  const char *fmt_attr = NULL;

  size = CADCHUNKALLOC;
  my_realloc(_ALLOC_ID_, &result, size);
  result[0] = '\0';

  my_strdup(_ALLOC_ID_, &template, (xctx->inst[inst].ptr + xctx->sym)->templ);
  my_strdup(_ALLOC_ID_, &name,xctx->inst[inst].instname);
  if (!name) my_strdup(_ALLOC_ID_, &name, get_tok_value(template, "name", 0));

  fmt_attr = xctx->format ? xctx->format : "spectre_format";
  /* allow format string override in instance */
  my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr, fmt_attr, 2));
  /* get netlist format rule from symbol */
  if(!xctx->tok_size)
    my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, fmt_attr, 2));
  /* allow format string override in instance */
  if(!xctx->tok_size && strcmp(fmt_attr, "spectre_format") )
    my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr, "spectre_format", 2));
  /* get netlist format rule from symbol */
  if(!xctx->tok_size && strcmp(fmt_attr, "spectre_format"))
     my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "spectre_format", 2));
  if ((name==NULL) || (format==NULL)) {
    my_free(_ALLOC_ID_, &template);
    my_free(_ALLOC_ID_, &format);
    my_free(_ALLOC_ID_, &name);
    my_free(_ALLOC_ID_, &result);
    return 0; /* do no netlist unwanted insts(no format) */
  }
  no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
  s=format;
  dbg(1, "print_spectre_element(): name=%s, format=%s xctx->netlist_count=%d\n",name,format, xctx->netlist_count);
  /* begin parsing format string */
  while(1)
  {
    /* always make room for some characters so the single char writes to result do not need reallocs */
    c=*s++;
    if(c=='\\') {
      escape=1;
      c=*s++;
    }
    else escape=0;

    if (c=='\n' && escape) c=*s++; /* 20171030 eat escaped newlines */
    space=SPACE(c);
    if ( state==TOK_BEGIN && (c=='@'|| c=='%')  && !escape ) state=TOK_TOKEN;
    else if(state==TOK_TOKEN && token_pos > 1 &&
       (
         ( (space  || c == '%' || c == '@') && !escape ) ||
         ( (!space && c != '%' && c != '@') && escape  )
       )
      ) {
      dbg(1, "print_spectre_element(): c=%c, space=%d, escape=%d token_pos=%d\n", c, space, escape, token_pos);
      state=TOK_SEP;
    }
    STR_ALLOC(&token, token_pos, &sizetok);
    if(state==TOK_TOKEN) {
      token[token_pos++]=(char)c;
    }
    else if (state==TOK_SEP)                    /* got a token */
    {
      char *val = NULL;
      size_t token_exists = 0;
      token[token_pos]='\0';
      token_pos=0;

      if(strcmp(token,"@symref")==0)
      {
        const char *s = get_sym_name(inst, 9999, 1, 0);
        my_mstrcat(_ALLOC_ID_, &result, s, NULL);
      }
      else if (strcmp(token,"@symname")==0) /* of course symname must not be present in attributes */
      {
        const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 0, 0)));
        my_mstrcat(_ALLOC_ID_, &result, s, NULL);
      }
      else if (strcmp(token,"@symname_ext")==0) /* of course symname_ext must not be present in attributes */
      {
        const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 1, 0)));
        my_mstrcat(_ALLOC_ID_, &result, s, NULL);
      }
      else if(strcmp(token,"@topschname")==0) /* of course topschname must not be present in attributes */
      {
        const char *topsch;
        topsch = get_trailing_path(xctx->sch[0], 0, 1);
        my_mstrcat(_ALLOC_ID_, &result, topsch, NULL);
      }
      else if(strcmp(token,"@schname_ext")==0) /* of course schname must not be present in attributes */
      {
        my_mstrcat(_ALLOC_ID_, &result, xctx->current_name, NULL);
      }
      else if(strcmp(token,"@savecurrent")==0)
      {
        char *instname = xctx->inst[inst].instname;

        const char *sc = get_tok_value(xctx->inst[inst].prop_ptr, "savecurrent", 0);
        if(!sc[0]) sc = get_tok_value(template, "savecurrent", 0);
        if(!strboolcmp(sc , "true")) {
          my_mstrcat(_ALLOC_ID_, &result, "\n.save I( ?1 ", instname, " )", NULL);
        }
      }
      else if(strcmp(token,"@schname")==0) /* of course schname must not be present in attributes */
      {
        const char *schname = get_cell(xctx->current_name, 0);
        my_mstrcat(_ALLOC_ID_, &result, schname, NULL);
      }
      else if(strcmp(token,"@pinlist")==0) /* of course pinlist must not be present in attributes */
                                           /* print multiplicity */
      {                                    /* and node number: m1 n1 m2 n2 .... */
        Int_hashtable table = {NULL, 0};
        int_hash_init(&table, 37);
        for(i=0;i<no_of_pins; ++i)
        {
          char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][i].prop_ptr;
          int spectre_ignore = !strboolcmp(get_tok_value(prop, "spectre_ignore", 0), "true");
          const char *name = get_tok_value(prop, "name", 0);
          if(!spectre_ignore) {
            if(!int_hash_lookup(&table, name, 1, XINSERT_NOREPLACE)) {
              str_ptr =  net_name(inst, i, &multip, 0, 1);

              my_mstrcat(_ALLOC_ID_, &result, "?", my_itoa(multip), " ", str_ptr, " ", NULL);
            }
          }
        }
        int_hash_free(&table);
      }
      else if(token[0]=='@' && token[1]=='@') {    /* recognize single pins 15112003 */
        for(i=0;i<no_of_pins; ++i) {
          char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][i].prop_ptr;
          if (!strcmp( get_tok_value(prop,"name",0), token+2)) {
            if(strboolcmp(get_tok_value(prop,"spectre_ignore",0), "true")) {
              str_ptr =  net_name(inst,i, &multip, 0, 1);

              my_mstrcat(_ALLOC_ID_, &result, "?", my_itoa(multip), " ", str_ptr, " ", NULL);
            }
            break;
          }
        }
      }
      /* reference by pin number instead of pin name, allows faster lookup of the attached net name
       * @#0, @#1:net_name, @#2:name, ... */
      else if(token[0]=='@' && token[1]=='#') {
        int n;
        char *pin_attr = NULL;
        char *pin_num_or_name = NULL;

        get_pin_and_attr(token, &pin_num_or_name, &pin_attr);
        n = get_inst_pin_number(inst, pin_num_or_name);
        if(n>=0  && pin_attr[0] && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
          char *pin_attr_value = NULL;
          int is_net_name = !strcmp(pin_attr, "net_name");
          /* get pin_attr value from instance: "pinnumber(ENABLE)=5" --> return 5, attr "pinnumber" of pin "ENABLE"
           *                                   "pinnumber(3)=6       --> return 6, attr "pinnumber" of 4th pin */
          if(!is_net_name) {
            pin_attr_value = get_pin_attr_from_inst(inst, n, pin_attr);
            /* get pin_attr from instance pin attribute string */
            if(!pin_attr_value) {
             my_strdup(_ALLOC_ID_, &pin_attr_value,
                get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][n].prop_ptr, pin_attr, 0));
            }
          }
          /* @#n:net_name attribute (n = pin number or name) will translate to net name attached  to pin */
          if(!pin_attr_value && is_net_name) {
            prepare_netlist_structs(0);
            my_strdup(_ALLOC_ID_, &pin_attr_value,
                 xctx->inst[inst].node && xctx->inst[inst].node[n] ? xctx->inst[inst].node[n] : "?");
          }
          if(!pin_attr_value ) my_strdup(_ALLOC_ID_, &pin_attr_value, "--UNDEF--");
          value = pin_attr_value;
          /* recognize slotted devices: instname = "U3:3", value = "a:b:c:d" --> value = "c" */
          if(value[0] && !strcmp(pin_attr, "pinnumber") ) {
            char *ss;
            int slot;
            char *tmpstr = NULL;
            tmpstr = my_malloc(_ALLOC_ID_, sizeof(xctx->inst[inst].instname));
            if( (ss=strchr(xctx->inst[inst].instname, ':')) ) {
              sscanf(ss+1, "%s", tmpstr);
              if(isonlydigit(tmpstr)) {
                slot = atoi(tmpstr);
                if(strstr(value,":")) value = find_nth(value, ":", "", 0, slot);
              }
            }
            my_free(_ALLOC_ID_, &tmpstr);
          }
          my_mstrcat(_ALLOC_ID_, &result, value, NULL);
          my_free(_ALLOC_ID_, &pin_attr_value);
        }
        else if(n>=0  && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
          const char *si;
          char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][n].prop_ptr;
          si  = get_tok_value(prop, "spectre_ignore",0);
          if(strboolcmp(si, "true")) {
            str_ptr =  net_name(inst,n, &multip, 0, 1);

            my_mstrcat(_ALLOC_ID_, &result, "?", my_itoa(multip), " ", str_ptr, " ", NULL);
          }
        }
        my_free(_ALLOC_ID_, &pin_attr);
        my_free(_ALLOC_ID_, &pin_num_or_name);
      }
      else if (!strncmp(token,"@tcleval", 8)) {
        size_t s;
        char *tclcmd=NULL;
        const char *res;
        s = token_pos + strlen(name) + strlen(xctx->inst[inst].name) + 100;
        tclcmd = my_malloc(_ALLOC_ID_, s);
        Tcl_ResetResult(interp);
        my_snprintf(tclcmd, s, "tclpropeval {%s} {%s} {%s}", token, name, xctx->inst[inst].name);
        dbg(1, "print_spectre_element(): tclpropeval {%s} {%s} {%s}", token, name, xctx->inst[inst].name);
        res = tcleval(tclcmd);

        my_mstrcat(_ALLOC_ID_, &result, res, NULL);
        my_free(_ALLOC_ID_, &tclcmd);
      }
      /* if spiceprefix==0 and token == @spiceprefix then set empty value */
      else if (!tclgetboolvar("spiceprefix") && !strcmp(token, "@spiceprefix")) {
        value=NULL;
      /* else tcl var spiceprefix is enabled  */
      }

      else {
        /* here a @token in format string will be replaced by value in instance prop_ptr
         * or symbol template */
        size_t tok_val_len;
        char *parent_prop_ptr = NULL;
        char *parent_templ = NULL;
        /* char *parent_sym_extra = NULL; */

        if(xctx->currsch > 0) {
          parent_prop_ptr = xctx->hier_attr[xctx->currsch - 1].prop_ptr;
          parent_templ = xctx->hier_attr[xctx->currsch - 1].templ;
          /* parent_sym_extra = xctx->hier_attr[xctx->currsch - 1].sym_extra; */
        }

        /* consider this scenario:
         * instance of passgate.sym: W_N=5 L_N=0.2 W_P=10 L_P=0.3 m=1
         * instance based schematic (schematic=mypippo attr) will have also modeln=pippon
         *    passgate.sym:
         *      format="@name @pinlist @symname W_N=@W_N L_N=@L_N W_P=@W_P L_P=@L_P m=@m"
         *      template=" ... modeln=nfet_01v8 modelp=pfet_01v8 m=1"
         *    passgate.sch:
         *       instance of nmos.sym: L=L_N W=W_N nf=1 m=1 model=@modeln
         *         nmos.sym:
         *           format="@name @pinlist @model L=@L W=@W nf=@nf
         *           + ad=@ad as=@as pd=@pd .... m=@m
         *           template="name=M1 W=1 L=0.15 m=1
         *             ad=\"expr('int((@nf + 1)/2) * @W / @nf * 0.29')\"
         *             ..."
         *           model=nfet_01v8
         */


        my_strdup2(_ALLOC_ID_, &val,
             translate3(token, 0, xctx->inst[inst].prop_ptr, NULL, NULL, NULL));
        /* can not put template in above translate3: ---------------------------^^^^
         * if instance has VHI=VHI, format string has VHI=@VHI, and symbol template has VHI=3
         * we do not want token @VHI to resolve to 3, but stop at VHI as specified in instance */
        if(strchr(val, '@')) {
           my_strdup2(_ALLOC_ID_, &val,
              translate3(val, 0, xctx->inst[inst].prop_ptr, parent_prop_ptr, template, NULL));
        }
        /* nmos instance format string: @model --> @modeln */
        dbg(1, "print_spectre_element(): 1st round: val: |%s|\n", val);
        if(strchr(val, '@')) {
          #if 0
          if(parent_prop_ptr) {
            my_strdup2(_ALLOC_ID_, &val,
                   translate3(val, 0, xctx->inst[inst].prop_ptr, parent_prop_ptr, parent_templ, NULL));
            /* instance based passgate.sym placement, nmos instance format string: @modeln --> pippon */
            /* ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')" --> ad="expr('int((1 + 1)/2) * W_N / 1 * 0.29')" */
            if(strchr(val, '@')) {
              my_strdup2(_ALLOC_ID_, &val,
                     translate3(val, 0, xctx->inst[inst].prop_ptr, parent_prop_ptr, parent_templ, NULL));
              /* ad="expr('int((1 + 1)/2) * W_N / 1 * 0.29')" --> ad="expr('int((1 + 1)/2) * 5 / 1 * 0.29')" */
            }
          } else {
          #endif
            my_strdup2(_ALLOC_ID_, &val,
                   translate3(val, 0, xctx->inst[inst].prop_ptr, NULL, NULL, NULL));
            dbg(1, "print_spectre_element(): 2nd round: val: |%s|\n", val);
            /* normal passgate.sym placement, nmos instance format string:
                 ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')" --> ad="expr('int((1 + 1)/2) * W_N/ 1 * 0.29')" */
            if(strchr(val, '@')) {
              my_strdup2(_ALLOC_ID_, &val,
                     translate3(val, 0, xctx->inst[inst].prop_ptr, parent_templ, NULL, NULL));
              dbg(1, "print_spectre_element(): 3nd round: val: |%s|\n", val);
              /* normal passgate.sym placement, nmos instance format string:
               *   @modeln --> nfet_01v8 */
            }
          #if 0
          }
          #endif
          dbg(1, "print_spectre_element(): final: val: |%s|\n", val);
        }
        /* still unresolved: set to empty */
        if(val[0] == '@') value = "";
        else value = val;
        token_exists = xctx->tok_size;
        tok_val_len = strlen(value);
        /* @spiceprefix needs a special tag for postprocessing */
        if(!strcmp(token, "@spiceprefix") && value[0]) {
          my_realloc(_ALLOC_ID_, &spiceprefixtag, tok_val_len+22);
          my_snprintf(spiceprefixtag, tok_val_len+22, "//// spice_prefix %s\n", value);
          value = spiceprefixtag;
        }

        if(is_expr(value)) {
          value =  eval_expr(value);
        }
        warn_hash_extra_node(inst, token + 1, value);   /* ERC, issue 0165 */
        /* token=%xxxx and xxxx is not defined in prop_ptr or template: return xxxx */
        if(!token_exists && token[0] =='%') {
          my_mstrcat(_ALLOC_ID_, &result, token + 1, NULL);
        }
        /* And finally set the value of token into result string */
        else if (value && value[0]!='\0') {
           /* instance names (name) and node labels (lab) go thru the expandlabel function. */
          /*if something else must be parsed, put an if here! */
          if (!(strcmp(token+1,"name") && strcmp(token+1,"lab"))  /* expand name/labels */
                && ((lab = expandlabel(value, &itmp)) != NULL)) {
            my_mstrcat(_ALLOC_ID_, &result, lab, NULL);
          } else {
            my_mstrcat(_ALLOC_ID_, &result, value, NULL);
          }
        }
      } /* else */

      /* append token separator to output result ... */
      if(c != '%' && c != '@' && c!='\0' ) {
        char str[2];
        str[0] = (unsigned char) c;
        str[1] = '\0';
        my_mstrcat(_ALLOC_ID_, &result, str, NULL);
      }
      /* ... unless it is the start of another token, so push back to input string */
      if(c == '@' || c == '%' ) s--;
      state=TOK_BEGIN;
      my_free(_ALLOC_ID_, &val);
    } /* else if (state==TOK_SEP) */

    else if(state==TOK_BEGIN && c!='\0') {
      char str[2];
      str[0] = (unsigned char) c;
      str[1] = '\0';
      my_mstrcat(_ALLOC_ID_, &result, str, NULL);
    }
    if(c=='\0')
    {
      char str[2];
      str[0] = '\n';
      str[1] = '\0';
      my_mstrcat(_ALLOC_ID_, &result, str, NULL);
      break;
    }
  } /* while(1) */


  /* if result is like: 'tcleval(some_string)' pass it thru tcl evaluation so expressions
   * can be calculated */
  if(result) {
     my_strdup(_ALLOC_ID_, &result, tcl_hook2(result));
  }
  if(is_expr(result)) {
    my_strdup2(_ALLOC_ID_, &result, eval_expr(result));
  }
  if(result) fprintf(fd, "%s", result);
  dbg(1, "print_spectre_element(): returning |%s|\n", result);
  my_free(_ALLOC_ID_, &template);
  my_free(_ALLOC_ID_, &format);
  my_free(_ALLOC_ID_, &name);
  my_free(_ALLOC_ID_, &token);
  my_free(_ALLOC_ID_, &result);
  if(spiceprefixtag) my_free(_ALLOC_ID_, &spiceprefixtag);
  /* my_free(_ALLOC_ID_, &translatedvalue); */
  return 1;
}

void print_tedax_element(FILE *fd, int inst)
{
 int i=0, multip;
 const char *str_ptr=NULL;
 register int c, state=TOK_BEGIN, space;
 char *template=NULL,*format=NULL,*s, *name=NULL, *token=NULL;
 const char *value;
 char *extra=NULL, *extra_pinnumber=NULL;
 char *numslots=NULL;
 const char *extra_token, *extra_token_val;
 char *extra_ptr;
 const char *extra_pinnumber_token;
 char *extra_pinnumber_ptr;
 char *saveptr1, *saveptr2;
 const char *tmp;
 int instance_based=0;
 size_t sizetok=0;
 size_t token_pos=0;
 int escape=0;
 int no_of_pins=0;
 int subcircuit = 0;

 my_strdup(_ALLOC_ID_, &extra, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr,"extra",0));
 my_strdup(_ALLOC_ID_, &extra_pinnumber, get_tok_value(xctx->inst[inst].prop_ptr,"extra_pinnumber",0));
 if(!extra_pinnumber) my_strdup(_ALLOC_ID_, &extra_pinnumber,
         get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr,"extra_pinnumber",0));
 my_strdup(_ALLOC_ID_, &template,
     (xctx->inst[inst].ptr + xctx->sym)->templ);
 my_strdup(_ALLOC_ID_, &numslots, get_tok_value(xctx->inst[inst].prop_ptr,"numslots",0));
 if(!numslots) my_strdup(_ALLOC_ID_, &numslots, get_tok_value(template,"numslots",0));
 if(!numslots) my_strdup(_ALLOC_ID_, &numslots, "1");

 my_strdup(_ALLOC_ID_, &name,xctx->inst[inst].instname);
 /* my_strdup(xxx, &name,get_tok_value(xctx->inst[inst].prop_ptr,"name",0)); */
 if(!name) my_strdup(_ALLOC_ID_, &name, get_tok_value(template, "name", 0));

 /* allow format string override in instance */
 my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr,"tedax_format",2));
 if(!format || !format[0])
   my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr,"tedax_format",2));

 no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
 if( !format && !strcmp((xctx->inst[inst].ptr + xctx->sym)->type, "subcircuit") ) {
   char *net = NULL;
   char *pinname = NULL;
   char *pin = NULL;
   char *netbit=NULL;
   char *pinbit = NULL;
   int net_mult;
   int pin_mult;
   int n;
   Int_hashtable table={NULL, 0};
   subcircuit = 1;
   fprintf(fd, "__subcircuit__ %s %s\n",
       sanitize(translate(inst, get_sym_name(inst, 0, 0, 0))), xctx->inst[inst].instname);
   int_hash_init(&table, 37);
   for(i=0;i<no_of_pins; ++i) {
     my_strdup2(_ALLOC_ID_, &net, net_name(inst,i, &net_mult, 0, 1));
     my_strdup2(_ALLOC_ID_, &pinname,
       get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][i].prop_ptr,"name",0));
     my_strdup2(_ALLOC_ID_, &pin, expandlabel(pinname, &pin_mult));
     if(!int_hash_lookup(&table, pinname, 1, XINSERT_NOREPLACE)) {
       dbg(1, "#net=%s pinname=%s pin=%s net_mult=%d pin_mult=%d\n", net, pinname, pin, net_mult, pin_mult);
       for(n = 0; n < net_mult; ++n) {
         my_strdup(_ALLOC_ID_, &netbit, find_nth(net, ",", "", 0, n+1));
         my_strdup(_ALLOC_ID_, &pinbit, find_nth(pin, ",", "", 0, n+1));
         fprintf(fd, "__map__ %s -> %s\n",
           pinbit ? pinbit : "__UNCONNECTED_PIN__",
           netbit ? netbit : "__UNCONNECTED_PIN__");
       }
     }
   }
   int_hash_free(&table);
   my_free(_ALLOC_ID_, &net);
   my_free(_ALLOC_ID_, &pin);
   my_free(_ALLOC_ID_, &pinname);
   my_free(_ALLOC_ID_, &pinbit);
   my_free(_ALLOC_ID_, &netbit);
   fprintf(fd, "\n");
 }

 if(name==NULL || !format || !format[0]) {
   my_free(_ALLOC_ID_, &extra);
   my_free(_ALLOC_ID_, &extra_pinnumber);
   my_free(_ALLOC_ID_, &template);
   my_free(_ALLOC_ID_, &numslots);
   my_free(_ALLOC_ID_, &format);
   my_free(_ALLOC_ID_, &name);
   return;
 }

 if(!subcircuit) {
   fprintf(fd, "begin_inst %s numslots %s\n", name, numslots);
   for(i=0;i<no_of_pins; ++i) {
     char *pinnumber;
     pinnumber = get_pin_attr_from_inst(inst, i, "pinnumber");
     if(!pinnumber) {
       my_strdup2(_ALLOC_ID_, &pinnumber,
              get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][i].prop_ptr,"pinnumber",0));
     }
     if(!xctx->tok_size) my_strdup(_ALLOC_ID_, &pinnumber, "--UNDEF--");
     tmp = net_name(inst,i, &multip, 0, 1);
     if(tmp && !strstr(tmp, "__UNCONNECTED_PIN__")) {
       fprintf(fd, "conn %s %s %s %s %d\n",
             name,
             tmp,
             get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][i].prop_ptr,"name",0),
             pinnumber,
             i+1);
     }
     my_free(_ALLOC_ID_, &pinnumber);
   }

   if(extra){
     char netstring[40];
     /* fprintf(errfp, "extra_pinnumber: |%s|\n", extra_pinnumber); */
     /* fprintf(errfp, "extra: |%s|\n", extra); */
     for(extra_ptr = extra, extra_pinnumber_ptr = extra_pinnumber; ; extra_ptr=NULL, extra_pinnumber_ptr=NULL) {
       /* extra= and extra_pinnumber= are walked in LOCKSTEP, but nothing keeps the two lists
        * the same length -- and my_strdup() leaves its destination NULL for an absent or empty
        * source, so a symbol carrying extra= and no extra_pinnumber= arrives here with
        * extra_pinnumber == NULL. my_strtok_r() only assigns *saveptr inside its `if(str)`
        * first-call branch, so a NULL first argument runs `while(**saveptr ...)` on an
        * UNINITIALISED saveptr1 -- an uncontrolled deref, and a segfault in practice. The
        * `extra` side is safe only by accident: the loop is entered only when extra != NULL.
        * Guard the call, and give a missing number the same placeholder the pin loop above
        * uses for a missing `pinnumber` attribute rather than passing NULL to "%s". Issue 0179. */
       extra_pinnumber_token = extra_pinnumber ?
              my_strtok_r(extra_pinnumber_ptr, " ", "", 0, &saveptr1) : NULL;
       extra_token=my_strtok_r(extra_ptr, " ", "", 0, &saveptr2);
       if(!extra_token) break;
       if(!extra_pinnumber_token) extra_pinnumber_token = "--UNDEF--";
       /* fprintf(errfp, "extra_pinnumber_token: |%s|\n", extra_pinnumber_token); */
       /* fprintf(errfp, "extra_token: |%s|\n", extra_token); */
       instance_based=0;

       /* alternate instance based extra net naming: net:<pinumber>=netname */
       my_snprintf(netstring, S(netstring), "net:%s", extra_pinnumber_token);
       dbg(1, "print_tedax_element(): netstring=%s\n", netstring);
       extra_token_val=get_tok_value(xctx->inst[inst].prop_ptr, extra_token, 0);
       if(!extra_token_val[0]) extra_token_val=get_tok_value(xctx->inst[inst].prop_ptr, netstring, 0);
       if(!extra_token_val[0]) extra_token_val=get_tok_value(template, extra_token, 0);
       else instance_based=1;
       if(!extra_token_val[0]) extra_token_val="--UNDEF--";

       fprintf(fd, "conn %s %s %s %s %d", name, extra_token_val, extra_token, extra_pinnumber_token, i+1);
       ++i;
       if(instance_based) fprintf(fd, " # instance_based");
       fprintf(fd,"\n");
     }
   }
 }
 if(format) {
  s=format;
  dbg(1, "print_tedax_element(): name=%s, tedax_format=%s xctx->netlist_count=%d\n",name,format, xctx->netlist_count);
  /* begin parsing format string */
  while(1)
  {
   c=*s++;
   if(c=='\\') {
     escape=1;
     c=*s++;
   }
   else escape=0;
   if(c=='\n' && escape ) c=*s++; /* 20171030 eat escaped newlines */
   space=SPACE(c);

   if( state==TOK_BEGIN && (c=='%' || c=='@') && !escape) state=TOK_TOKEN;
   else if(state==TOK_TOKEN && token_pos > 1 &&
      (
        ( (space  || c == '%' || c == '@') && !escape ) ||
        ( (!space && c != '%' && c != '@') && escape  )
      )
     ) {
     state=TOK_SEP;
   }

   STR_ALLOC(&token, token_pos, &sizetok);
   if(state==TOK_TOKEN) {
     token[token_pos++]=(char)c; /* 20171029 remove escaping backslashes */
   }
   else if(state==TOK_SEP)                   /* got a token */
   {
    token[token_pos]='\0';
    token_pos=0;

    value = get_tok_value(xctx->inst[inst].prop_ptr, token+1, 0);
     /* xctx->tok_size==0 indicates that token(+1) does not exist in instance attributes */
    if(!xctx->tok_size) value=get_tok_value(template, token+1, 0);
    if(!xctx->tok_size && token[0] =='%') {
      fputs(token + 1, fd);
    } else if(value[0]!='\0')
    {
      fputs(value,fd);
    }
    else if(strcmp(token,"@symref")==0)
    {
      const char *s = get_sym_name(inst, 9999, 1, 0);
      fputs(s, fd);
    }
    else if(strcmp(token,"@symname")==0)        /* of course symname must not be present  */
                                        /* in hash table */
    {
      const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 0, 0)));
      fputs(s, fd);
    }
    else if (strcmp(token,"@symname_ext")==0)
    {
      const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 1, 0)));
      fputs(s, fd);
    }
    else if(strcmp(token,"@schname_ext")==0)        /* of course schname must not be present  */
                                                /* in hash table */
    {
     /* fputs(xctx->sch[xctx->currsch],fd); */
     fputs(xctx->current_name, fd);
    }
    else if(strcmp(token,"@schname")==0)        /* of course schname must not be present  */
                                                /* in hash table */
    {
     fputs(get_cell(xctx->current_name, 0), fd);
    }
    else if(strcmp(token,"@topschname")==0) /* of course topschname must not be present in attributes */
    {
      const char *topsch;
      topsch = get_trailing_path(xctx->sch[0], 0, 1);
      fputs(topsch, fd);
    }
    else if(strcmp(token,"@pinlist")==0)
                                        /* print multiplicity */
    {                                   /* and node number: m1 n1 m2 n2 .... */
     for(i=0;i<no_of_pins; ++i)
     {
       str_ptr =  net_name(inst,i, &multip, 0, 1);
       /* fprintf(errfp, "inst: %s  --> %s\n", name, str_ptr); */
       fprintf(fd, "?%d %s ", multip, str_ptr);
     }
    }
    else if(token[0]=='@' && token[1]=='@') {    /* recognize single pins 15112003 */
     for(i=0;i<no_of_pins; ++i) {
      if(!strcmp(
           get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][i].prop_ptr,"name",0),
           token+2
          )
        ) {
        str_ptr =  net_name(inst,i, &multip, 0, 1);
        fprintf(fd, "%s", str_ptr);
        break;
      }
     }
    }
    /* this allow to print in netlist any properties defined for pins.
     * @#n:property, where 'n' is the pin index (starting from 0) and
     * 'property' the property defined for that pin (property=value)
     * in case this property is found the value for it is printed.
     * if device is slotted (U1:m) and property value for pin
     * is also slotted ('a:b:c:d') then print the m-th substring.
     * if property value is not slotted print entire value regardless of device slot.
     * slot numbers start from 1
     */
    else if(token[0]=='@' && token[1]=='#') {
      int n;
      char *pin_attr = NULL;
      char *pin_num_or_name = NULL;

      get_pin_and_attr(token, &pin_num_or_name, &pin_attr);
      n = get_inst_pin_number(inst, pin_num_or_name);
      if(n>=0  && pin_attr[0] && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
        char *pin_attr_value = NULL;
        int is_net_name = !strcmp(pin_attr, "net_name");
        /* get pin_attr value from instance: "pinnumber(ENABLE)=5" --> return 5, attr "pinnumber" of pin "ENABLE"
         *                                   "pinnumber(3)=6       --> return 6, attr "pinnumber" of 4th pin */
        if(!is_net_name) {
          pin_attr_value = get_pin_attr_from_inst(inst, n, pin_attr);
          /* get pin_attr from instance pin attribute string */
          if(!pin_attr_value) {
           my_strdup(_ALLOC_ID_, &pin_attr_value,
              get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][n].prop_ptr, pin_attr, 0));
          }
        }
        /* @#n:net_name attribute (n = pin number or name) will translate to net name attached  to pin */
        if(!pin_attr_value && is_net_name) {
          prepare_netlist_structs(0);
          my_strdup(_ALLOC_ID_, &pin_attr_value,
               xctx->inst[inst].node && xctx->inst[inst].node[n] ? xctx->inst[inst].node[n] : "?");
        }
        if(!pin_attr_value ) my_strdup(_ALLOC_ID_, &pin_attr_value, "--UNDEF--");
        value = pin_attr_value;
        /* recognize slotted devices: instname = "U3:3", value = "a:b:c:d" --> value = "c" */
        if(value[0] && !strcmp(pin_attr, "pinnumber")) {
          char *ss;
          int slot;
          char *tmpstr = NULL;
          tmpstr = my_malloc(_ALLOC_ID_, sizeof(xctx->inst[inst].instname));
          if( (ss=strchr(xctx->inst[inst].instname, ':')) ) {
            sscanf(ss+1, "%s", tmpstr);
            if(isonlydigit(tmpstr)) {
              slot = atoi(tmpstr);
              if(strstr(value,":")) value = find_nth(value, ":", "", 0, slot);
            }
          }
          my_free(_ALLOC_ID_, &tmpstr);
        }
        fprintf(fd, "%s", value);
        my_free(_ALLOC_ID_, &pin_attr_value);
      }
      else if(n>=0  && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
        const char *si;
        char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][n].prop_ptr;
        si  = get_tok_value(prop, "tedax_ignore",0);
        if(strboolcmp(si, "true")) {
          str_ptr =  net_name(inst,n, &multip, 0, 1);
          fprintf(fd, "%s", str_ptr);
        }
      }
      my_free(_ALLOC_ID_, &pin_attr);
      my_free(_ALLOC_ID_, &pin_num_or_name);
    }
    else if(!strncmp(token,"@tcleval", 8)) {
      /* char tclcmd[strlen(token)+100] ; */
      size_t s;
      char *tclcmd=NULL;
      s = token_pos + strlen(name) + strlen(xctx->inst[inst].name) + 100;
      tclcmd = my_malloc(_ALLOC_ID_, s);
      Tcl_ResetResult(interp);
      my_snprintf(tclcmd, s, "tclpropeval {%s} {%s} {%s}", token, name, xctx->inst[inst].name);
      tcleval(tclcmd);
      fprintf(fd, "%s", tclresult());
      my_free(_ALLOC_ID_, &tclcmd);
      /* fprintf(errfp, "%s\n", tclcmd); */
    } /* /20171029 */


    if(c!='%' && c!='@' && c!='\0') fputc(c,fd);
    if(c == '@' || c == '%' ) s--;
    state=TOK_BEGIN;
   }
   else if(state==TOK_BEGIN && c!='\0')  fputc(c,fd);
   if(c=='\0')
   {
    fputc('\n',fd);
    break ;
   }
  }
 } /* if(format) */
 if(!subcircuit) fprintf(fd,"end_inst\n");
 my_free(_ALLOC_ID_, &extra);
 my_free(_ALLOC_ID_, &extra_pinnumber);
 my_free(_ALLOC_ID_, &template);
 my_free(_ALLOC_ID_, &numslots);
 my_free(_ALLOC_ID_, &format);
 my_free(_ALLOC_ID_, &name);
 my_free(_ALLOC_ID_, &token);
}

/* print verilog element if verilog_format is specified */
static void print_verilog_primitive(FILE *fd, int inst) /* netlist switch level primitives, 15112003 */
{
  int i=0, multip, tmp;
  const char *str_ptr;
  register int c, state=TOK_BEGIN, space;
  const char *lab;
  char *template=NULL,*format=NULL,*s=NULL, *name=NULL, *token=NULL;
  const char *value;
  size_t sizetok=0;
  size_t token_pos=0;
  int escape=0;
  int no_of_pins=0;
  int symbol = xctx->inst[inst].ptr;
  const char *fmt_attr = NULL;
  char *result = NULL;

  my_strdup(_ALLOC_ID_, &template,
      (xctx->inst[inst].ptr + xctx->sym)->templ);

  my_strdup(_ALLOC_ID_, &name,xctx->inst[inst].instname);
  if(!name) my_strdup(_ALLOC_ID_, &name, get_tok_value(template, "name", 0));

  fmt_attr = xctx->format ? xctx->format : "verilog_format";
  /* allow format string override in instance */
  my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr, fmt_attr, 2));
  /* get netlist format rule from symbol */
  if(!xctx->tok_size)
    my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, fmt_attr, 2));
  /* allow format string override in instance */
  if(!xctx->tok_size && strcmp(fmt_attr, "verilog_format") )
    my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->inst[inst].prop_ptr, "verilog_format", 2));
  /* get netlist format rule from symbol */
  if(!xctx->tok_size && strcmp(fmt_attr, "verilog_format"))
     my_strdup(_ALLOC_ID_, &format, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "verilog_format", 2));
  if((name==NULL) || (format==NULL) ) {
    my_free(_ALLOC_ID_, &template);
    my_free(_ALLOC_ID_, &name);
    my_free(_ALLOC_ID_, &format);
    return; /*do no netlist unwanted insts(no format) */
  }
  no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
  s=format;
  dbg(1, "print_verilog_primitive(): name=%s, format=%s xctx->netlist_count=%d\n",name,format, xctx->netlist_count);

  fprintf(fd, "---- start primitive ");
  lab=expandlabel(name, &tmp);
  fprintf(fd, "%d\n",tmp);
  /* begin parsing format string */
  while(1)
  {
   c=*s++;
   if(c=='\\') {
     escape=1;
     c=*s++;
   }
   else escape=0;
   if(c=='\n' && escape ) c=*s++; /* 20171030 eat escaped newlines */
   space=SPACE(c);
   if( state==TOK_BEGIN && (c=='@' || c=='%') && !escape ) state=TOK_TOKEN;
   else if(state==TOK_TOKEN && token_pos > 1 &&
      (
        ( (space  || c == '%' || c == '@') && !escape ) ||
        ( (!space && c != '%' && c != '@') && escape  )
      )
     ) {
     state=TOK_SEP;
   }

   STR_ALLOC(&token, token_pos, &sizetok);
   if(state==TOK_TOKEN) {
      token[token_pos++]=(char)c;
   }
   else if(state==TOK_SEP)                    /* got a token */
   {
    token[token_pos]='\0';
    token_pos=0;

    value = get_tok_value(xctx->inst[inst].prop_ptr, token+1, 0);
    /* xctx->tok_size==0 indicates that token(+1) does not exist in instance attributes */
    if(!xctx->tok_size)
    value=get_tok_value(template, token+1, 0);
    if(!xctx->tok_size && token[0] =='%') {
      my_mstrcat(_ALLOC_ID_, &result, token + 1, NULL);
    } else if(value && value[0]!='\0') {
       /* instance names (name) and node labels (lab) go thru the expandlabel function. */
       /*if something else must be parsed, put an if here! */

     if(!(strcmp(token+1,"name"))) {
       if( (lab=expandlabel(value, &tmp)) != NULL)
          my_mstrcat(_ALLOC_ID_, &result, "----name(", lab, ")", NULL);
       else
          my_mstrcat(_ALLOC_ID_, &result, value, NULL);
     }
     else if(!(strcmp(token+1,"lab"))) {
       if( (lab=expandlabel(value, &tmp)) != NULL)
          my_mstrcat(_ALLOC_ID_, &result, "----pin(", lab, ")", NULL);
       else
          my_mstrcat(_ALLOC_ID_, &result, value, NULL);
     }
     else my_mstrcat(_ALLOC_ID_, &result, value, NULL);
    }
    else if(strcmp(token,"@symref")==0)
    {
      const char *s = get_sym_name(inst, 9999, 1, 0);
      my_mstrcat(_ALLOC_ID_, &result, s, NULL);
    }
    else if(strcmp(token,"@symname")==0) /* of course symname must not be present  */
                                         /* in hash table */
    {
      const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 0, 0)));
      my_mstrcat(_ALLOC_ID_, &result, s, NULL);
    }
    else if (strcmp(token,"@symname_ext")==0)
    {
      const char *s = sanitize(translate(inst, get_sym_name(inst, 0, 1, 0)));
      my_mstrcat(_ALLOC_ID_, &result, s, NULL);
    }
    else if(strcmp(token,"@schname_ext")==0) /* of course schname must not be present  */
                                         /* in hash table */
    {
      my_mstrcat(_ALLOC_ID_, &result, xctx->current_name, NULL);
    }
    else if(strcmp(token,"@schname")==0) /* of course schname must not be present  */
                                         /* in hash table */
    {
      my_mstrcat(_ALLOC_ID_, &result, get_cell(xctx->current_name, 0), NULL);
    }
    else if(strcmp(token,"@topschname")==0) /* of course topschname must not be present in attributes */
    {
      const char *topsch;
      topsch = get_trailing_path(xctx->sch[0], 0, 1);
      my_mstrcat(_ALLOC_ID_, &result, topsch, NULL);
    }
    else if(strcmp(token,"@pinlist")==0) /* of course pinlist must not be present  */
                                         /* in hash table. print multiplicity */
    {                                    /* and node number: m1 n1 m2 n2 .... */
     Int_hashtable table = {NULL, 0};
     int first = 1;
     int_hash_init(&table, 37);
     for(i=0;i<no_of_pins; ++i) {
       if(strboolcmp(get_tok_value(xctx->sym[symbol].rect[PINLAYER][i].prop_ptr,"verilog_ignore",0), "true")) {
         const char *name = get_tok_value(xctx->sym[symbol].rect[PINLAYER][i].prop_ptr,"name",0);
         if(!int_hash_lookup(&table, name, 1, XINSERT_NOREPLACE)) {
           if(!first) my_mstrcat(_ALLOC_ID_, &result, " , ", NULL);
           str_ptr =  net_name(inst,i, &multip, 0, 1);
           my_mstrcat(_ALLOC_ID_, &result, "----pin(", str_ptr, ") ", NULL);
           first = 0;
         }
       }
     }
     int_hash_free(&table);
    }
    else if(token[0]=='@' && token[1]=='@') {    /* recognize single pins 15112003 */
     for(i=0;i<no_of_pins; ++i) {
      char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][i].prop_ptr;
      if(!strcmp( get_tok_value(prop,"name",0), token+2)) {
        str_ptr =  net_name(inst,i, &multip, 0, 1);
        my_mstrcat(_ALLOC_ID_, &result, "----pin(", str_ptr, ") ", NULL);
        break;
      }
     }
    }

    /* reference by pin number instead of pin name, allows faster lookup of the attached net name
     * @#0, @#1:net_name, @#2:name, ... */
    else if(token[0]=='@' && token[1]=='#') {
      int n;
      char *pin_attr = NULL;
      char *pin_num_or_name = NULL;

      get_pin_and_attr(token, &pin_num_or_name, &pin_attr);
      n = get_inst_pin_number(inst, pin_num_or_name);
      if(n>=0  && pin_attr[0] && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
        char *pin_attr_value = NULL;
        int is_net_name = !strcmp(pin_attr, "net_name");
        /* get pin_attr value from instance: "pinnumber(ENABLE)=5" --> return 5, attr "pinnumber" of pin "ENABLE"
         *                                   "pinnumber(3)=6       --> return 6, attr "pinnumber" of 4th pin */
        if(!is_net_name) {
          pin_attr_value = get_pin_attr_from_inst(inst, n, pin_attr);
          /* get pin_attr from instance pin attribute string */
          if(!pin_attr_value) {
           my_strdup(_ALLOC_ID_, &pin_attr_value,
              get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][n].prop_ptr, pin_attr, 0));
          }
        }
        /* @#n:net_name attribute (n = pin number or name) will translate to net name attached  to pin */
        if(!pin_attr_value && is_net_name) {
          prepare_netlist_structs(0);
          my_strdup(_ALLOC_ID_, &pin_attr_value,
               xctx->inst[inst].node && xctx->inst[inst].node[n] ? xctx->inst[inst].node[n] : "?");
        }
        if(!pin_attr_value ) my_strdup(_ALLOC_ID_, &pin_attr_value, "--UNDEF--");
        value = pin_attr_value;
        /* recognize slotted devices: instname = "U3:3", value = "a:b:c:d" --> value = "c" */
        if(value[0] && !strcmp(pin_attr, "pinnumber") ) {
          char *ss;
          int slot;
          char *tmpstr = NULL;
          tmpstr = my_malloc(_ALLOC_ID_, sizeof(xctx->inst[inst].instname));
          if( (ss=strchr(xctx->inst[inst].instname, ':')) ) {
            sscanf(ss+1, "%s", tmpstr);
            if(isonlydigit(tmpstr)) {
              slot = atoi(tmpstr);
              if(strstr(value,":")) value = find_nth(value, ":", "", 0, slot);
            }
          }
          my_free(_ALLOC_ID_, &tmpstr);
        }
        my_mstrcat(_ALLOC_ID_, &result, value, NULL);
        my_free(_ALLOC_ID_, &pin_attr_value);
      }
      else if(n>=0  && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
        const char *si;
        char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][n].prop_ptr;
        si  = get_tok_value(prop, "verilog_ignore",0);
        if(strboolcmp(si, "true")) {
          str_ptr =  net_name(inst,n, &multip, 0, 1);
          my_mstrcat(_ALLOC_ID_, &result, "----pin(", str_ptr, ") ", NULL);
        }
      }
      my_free(_ALLOC_ID_, &pin_attr);
      my_free(_ALLOC_ID_, &pin_num_or_name);
    }

    else if(!strncmp(token,"@tcleval", 8)) {
      /* char tclcmd[strlen(token)+100] ; */
      size_t s;
      char *tclcmd=NULL;
      s = token_pos + strlen(name) + strlen(xctx->inst[inst].name) + 100;
      tclcmd = my_malloc(_ALLOC_ID_, s);
      Tcl_ResetResult(interp);
      my_snprintf(tclcmd, s, "tclpropeval {%s} {%s} {%s}", token, name, xctx->inst[inst].name);
      tcleval(tclcmd);
      my_mstrcat(_ALLOC_ID_, &result, tclresult(), NULL);
      my_free(_ALLOC_ID_, &tclcmd);
    }
    if(c!='%' && c!='@' && c!='\0') {
      char str[2];
      str[0] = (unsigned char) c;
      str[1] = '\0';
      my_mstrcat(_ALLOC_ID_, &result, str, NULL);
    }
    if(c == '@' || c == '%') s--;
    state=TOK_BEGIN;
   }
   else if(state==TOK_BEGIN && c!='\0')  {
     char str[2];
     str[0] = (unsigned char) c;
     str[1] = '\0';
     my_mstrcat(_ALLOC_ID_, &result, str, NULL);
   }
   if(c=='\0')
   {
    char *parent_prop_ptr = NULL;

    if(xctx->currsch > 0) {
      parent_prop_ptr = xctx->hier_attr[xctx->currsch - 1].prop_ptr;
    }

    /* if result is like: 'tcleval(some_string)' pass it thru tcl evaluation so expressions
     * can be calculated. Before that do also a round of translation to remove remaining @params */
    if(result) {
      dbg(1, "print_verilog_primitive(): before translate3() result=%s\n", result);
      if(strchr(result, '@')) {
        /* netlist_commands often have @ characters due to ngspice syntax. Do not translate */
        if(strcmp(xctx->sym[xctx->inst[inst].ptr].type, "netlist_commands")) {
          my_strdup2(_ALLOC_ID_, &result,
            translate3(result, 0, xctx->inst[inst].prop_ptr, parent_prop_ptr, NULL, NULL));
          /* can not put template in above translate3: -----------------------^^^^
           * if instance has VHI=VHI, format string has VHI=@VHI, and symbol template has VHI=3
           * we do not want token @VHI to resolve to 3, but stop at VHI as specified in instance */
          if(strchr(result, '@')) {
             my_strdup2(_ALLOC_ID_, &result,
                translate3(result, 0, xctx->inst[inst].prop_ptr, parent_prop_ptr, template, NULL));
          }
        }
      }
      my_strdup2(_ALLOC_ID_, &result, tcl_hook2(result)); /* tcl evaluation if tcleval(....) */
      if(is_expr(result)) {
        my_strdup2(_ALLOC_ID_, &result, eval_expr(result));
      }
      dbg(1, "print_verilog_primitive(): after  translate3() result=%s\n", result);
    }
    if(result) fprintf(fd, "%s", result);
    fputc('\n',fd);
    fprintf(fd, "---- end primitive\n");
    break ;
   }
  } /* while(1) */
  my_free(_ALLOC_ID_, &result);
  my_free(_ALLOC_ID_, &template);
  my_free(_ALLOC_ID_, &format);
  my_free(_ALLOC_ID_, &name);
  my_free(_ALLOC_ID_, &token);
}

/* verilog module instantiation:
     cmos_inv
     #(
     .WN ( 1.5e-05 ) ,
     .WP ( 4.5e-05 ) ,
     .LLN ( 3e-06 ) ,
     .LLP ( 3e-06 )
     )
     Xinv (
      .A( AA ),
      .Z( Z )
     );
*/
void print_verilog_element(FILE *fd, int inst)
{
 int i=0, multip, tmp;
 const char *str_ptr;
 const char *lab;
 char *name=NULL, *symname = NULL;
 char  *generic_type=NULL;
 char *template=NULL, *verilogprefix = NULL, *s;
 int no_of_pins=0;
 int  tmp1 = 0;
 register int c, state=TOK_BEGIN, space;
 char *value=NULL,  *token=NULL, *extra = NULL, *v_extra = NULL;
 char *extra_ptr, *saveptr1, *extra_token;
 size_t sizetok=0, sizeval=0;
 size_t token_pos=0, value_pos=0;
 int quote=0;
 const char *fmt_attr = NULL;
 Int_hashtable table = {NULL, 0};
 const char *fmt;

 fmt_attr = xctx->format ? xctx->format : "verilog_format";

 /* allow format string override in instance */
 fmt = get_tok_value(xctx->inst[inst].prop_ptr, fmt_attr, 2);
 /* get netlist format rule from symbol */
 if(!xctx->tok_size)
   fmt = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, fmt_attr, 2);
 /* allow format string override in instance */
 if(!xctx->tok_size && strcmp(fmt_attr, "verilog_format") )
   fmt = get_tok_value(xctx->inst[inst].prop_ptr, "verilog_format", 2);
 /* get netlist format rule from symbol */
 if(!xctx->tok_size && strcmp(fmt_attr, "verilog_format"))
   fmt = get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "verilog_format", 2);

 if(fmt[0]) {
  print_verilog_primitive(fd, inst);
  return;
 }

 my_strdup(_ALLOC_ID_, &name,xctx->inst[inst].instname);
 if(!name) my_strdup(_ALLOC_ID_, &name, get_tok_value(template, "name", 0));
 if(name==NULL) {
   my_free(_ALLOC_ID_, &name);
   return;
 }
 /* verilog_extra is the list of additional nodes passed as attributes */
 my_strdup(_ALLOC_ID_, &v_extra, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "verilog_extra", 0));
 /* extra is the list of attributes NOT to consider as instance parameters */
 my_strdup(_ALLOC_ID_, &extra, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "extra", 0));
 my_strdup(_ALLOC_ID_, &verilogprefix,
    get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr, "verilogprefix", 0));
 if(verilogprefix) {
   my_strdup(_ALLOC_ID_, &symname, verilogprefix);
   my_strcat(_ALLOC_ID_, &symname, get_sym_name(inst, 0, 0, 0));
 } else {
   my_strdup(_ALLOC_ID_, &symname, get_sym_name(inst, 0, 0, 0));
 }
 my_free(_ALLOC_ID_, &verilogprefix);
 my_strdup(_ALLOC_ID_, &template, (xctx->inst[inst].ptr + xctx->sym)->templ);
 no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];

 /* 20080915 use generic_type property to decide if some properties are strings, see later */
 my_strdup(_ALLOC_ID_, &generic_type, get_tok_value(xctx->sym[xctx->inst[inst].ptr].prop_ptr,"generic_type",0));
 s=xctx->inst[inst].prop_ptr;
/* print instance  subckt */
 dbg(2, "print_verilog_element(): printing inst name & subcircuit name\n");
 fprintf(fd, "%s\n", sanitize(symname));
 my_free(_ALLOC_ID_, &symname);
 /* -------- print generics passed as properties */
 tmp=0;
 while(1)
 {
   if (s==NULL) break;
  c=*s++;
  if(c=='\\')
  {
    c=*s++;
  }
  space=SPACE(c);
  if( (state==TOK_BEGIN || state==TOK_ENDTOK) && !space && c != '=') state=TOK_TOKEN;
  else if( state==TOK_TOKEN && space) state=TOK_ENDTOK;
  else if( (state==TOK_TOKEN || state==TOK_ENDTOK) && c=='=') state=TOK_SEP;
  else if( state==TOK_SEP && !space) state=TOK_VALUE;
  else if( state==TOK_VALUE && space && !quote) state=TOK_END;

  STR_ALLOC(&value, value_pos, &sizeval);
  STR_ALLOC(&token, token_pos, &sizetok);
  if(state==TOK_TOKEN) token[token_pos++]=(char)c;
  else if(state==TOK_VALUE)
  {
    value[value_pos++]=(char)c;
  }
  else if(state==TOK_ENDTOK || state==TOK_SEP) {
    if(token_pos) {
      token[token_pos]='\0';
      token_pos=0;
    }
  } else if(state==TOK_END)
  {
   value[value_pos]='\0';
   value_pos=0;
   get_tok_value(template, token, 0);
   dbg(1, "token=%s, extra=%s\n", token, extra);
   if(strcmp(token, "name") && xctx->tok_size && (!extra || !strstr(extra, token))) {
     if(value[0] != '\0') /* token has a value */
     {
       if(strcmp(token,"spice_ignore") && strcmp(token,"vhdl_ignore") &&
          strcmp(token,"tedax_ignore") && strcmp(token,"spectre_ignore")) {
         if(tmp == 0) {
           fprintf(fd, "#(\n---- start parameters\n");
           ++tmp;
           tmp1=0;
         }
         /* skip attributes of type time (delay="20 ns") that have VHDL syntax */
         if( !generic_type || strcmp(get_tok_value(generic_type,token, 0), "time")  ) {
           if(tmp1) fprintf(fd, " ,\n");
           if( generic_type && !strcmp(get_tok_value(generic_type,token, 0), "string")  ) {
             fprintf(fd, "  .%s ( \"%s\" )", token, value);
           } else {
             fprintf(fd, "  .%s ( %s )", token, value);
           }
           tmp1=1;
         }
       }
     }
   }
   state=TOK_BEGIN;
  }
  if(c=='\0')  /* end string */
  {
   break ;
  }
 }
 if(tmp) fprintf(fd, "\n---- end parameters\n)\n");

 /* -------- end print generics passed as properties */

/* print instance name */
 if( (lab = expandlabel(name, &tmp)) != NULL)
   fprintf(fd, "---- instance %s (\n", lab );
 else  /*  name in some strange format, probably an error */
   fprintf(fd, "---- instance %s (\n", name );

  dbg(2, "print_verilog_element(): printing port maps \n");
 /* print port map */
 tmp=0;
 int_hash_init(&table, 37);
 for(i=0;i<no_of_pins; ++i)
 {
   xSymbol *ptr = xctx->inst[inst].ptr + xctx->sym;
   if(strboolcmp(get_tok_value(ptr->rect[PINLAYER][i].prop_ptr,"verilog_ignore",0), "true")) {
     const char *name = get_tok_value(ptr->rect[PINLAYER][i].prop_ptr, "name", 0);
     if(!int_hash_lookup(&table, name, 1, XINSERT_NOREPLACE)) {
       if( (str_ptr =  net_name(inst,i, &multip, 0, 1)) )
       {
         if(tmp) fprintf(fd,"\n");
         fprintf(fd, "  ?%d %s %s ", multip, get_tok_value(ptr->rect[PINLAYER][i].prop_ptr,"name",0), str_ptr);
         tmp=1;
       }
     }
   }
 }
 int_hash_free(&table);
 if(v_extra) {
   const char *val;
   for(extra_ptr = v_extra; ; extra_ptr=NULL) {
     extra_token=my_strtok_r(extra_ptr, " ", "", 0, &saveptr1);
     if(!extra_token) break;

     val = get_tok_value(xctx->inst[inst].prop_ptr, extra_token, 0);
     if(!val[0]) val = get_tok_value(template, extra_token, 0);
     if(tmp) fprintf(fd,"\n");
     fprintf(fd, "  ?%d %s %s ", 1, extra_token, val);
     tmp = 1;
   }
 }


 fprintf(fd, "\n);\n\n");
 dbg(2, "print_verilog_element(): ------- end ------ \n");
 my_free(_ALLOC_ID_, &name);
 my_free(_ALLOC_ID_, &generic_type);
 my_free(_ALLOC_ID_, &template);
 my_free(_ALLOC_ID_, &value);
 my_free(_ALLOC_ID_, &token);
 my_free(_ALLOC_ID_, &extra);
 my_free(_ALLOC_ID_, &v_extra);
}


const char *net_name(int i, int j, int *multip, int hash_prefix_unnamed_net, int erc)
{
 int tmp, k;
 char errstr[2048];
 char unconn[50];
 char str_node[40]; /* 20161122 overflow safe */

 xSymbol *sym = xctx->inst[i].ptr + xctx->sym;
 int no_of_pins= sym->rects[PINLAYER];
 char *pinname = NULL;


 /* if merging a ngspice_probe.sym element it contains a @@p token,
  * so translate calls net_name, but we are placing the merged objects,
  * no net name is assigned yet */
 if(!xctx->inst[i].node) {
   return expandlabel("", multip);
 }
 if(xctx->inst[i].node && xctx->inst[i].node[j] == NULL)
 {
   my_strdup(_ALLOC_ID_, &pinname, get_tok_value( sym->rect[PINLAYER][j].prop_ptr,"name",0));
   /* before reporting unconnected pin try to locate duplicated pin and use it if found */
   for(k = 0; k < no_of_pins; ++k) {
     const char *duplicated_pinname;
     if(k == j) continue;
     duplicated_pinname =  get_tok_value( sym->rect[PINLAYER][k].prop_ptr,"name",0);
     if(!strcmp(duplicated_pinname , pinname)) {
       my_strdup(_ALLOC_ID_, &pinname, duplicated_pinname);
       j = k;
       break;
     }
   }
 }
 /* can not merge this if() with previous one, since j may be changed here */
 if(xctx->inst[i].node && xctx->inst[i].node[j] == NULL)
 {
   expandlabel(pinname, multip);
   if(pinname) my_free(_ALLOC_ID_, &pinname);
   if(erc) {
     my_snprintf(errstr, S(errstr), "Warning: unconnected pin,  Inst idx: %d, Pin idx: %d  Inst:%s\n",
                 i, j, xctx->inst[i].instname ) ;
     statusmsg(errstr,2);
     if(!xctx->netlist_count && xctx->netlist_type != CAD_TEDAX_NETLIST) {
       xctx->inst[i].color = -PINLAYER;
       xctx->hilight_nets=1;
     }
   }
   if(*multip <= 1)
     my_snprintf(unconn, S(unconn), "__UNCONNECTED_PIN__%d", xctx->netlist_unconn_cnt++);
   else
     my_snprintf(unconn, S(unconn), "__UNCONNECTED_PIN__%d_[%d..0]", xctx->netlist_unconn_cnt++, *multip - 1);
   return expandlabel(unconn, &tmp);
 }
 else { /* xctx->inst[i].node[j] not NULL */
   if(pinname) my_free(_ALLOC_ID_, &pinname);
   if((xctx->inst[i].node[j])[0] == '#') /* unnamed net */
   {
     /* Get unnamed node multiplicity (minimum multip found in circuit). The branch test stays
      * LOOSE because the name emission below also strips the '#' for ANY such name -- but the
      * INDEX is strict (issue 0156): only "#net<N>" carries an index at +4. A user-authored
      * '#foo' used to reach atoi("o") == 0 here and silently borrow node 0's multiplicity,
      * which could declare a scalar user net as a bus in the netlist. Treat it as scalar,
      * the same fallback node_hash.c uses for a non-auto name. */
     *multip = is_auto_net_name(xctx->inst[i].node[j]) ?
                 get_unnamed_node(3, 0, atoi((xctx->inst[i].node[j])+4) ) : 1;
     dbg(2, "net_name(): node = %s  n=%d multip=%d\n",
     xctx->inst[i].node[j], atoi(xctx->inst[i].node[j]), *multip);
     if(hash_prefix_unnamed_net) {
       if(*multip>1)   /* unnamed is a bus */
         my_snprintf(str_node, S(str_node), "%s_[%d..0]", (xctx->inst[i].node[j]), *multip-1);
       else
         my_snprintf(str_node, S(str_node), "%s", (xctx->inst[i].node[j]) );
     } else {
       if(*multip>1)   /* unnamed is a bus */
         my_snprintf(str_node, S(str_node), "%s_[%d..0]", (xctx->inst[i].node[j])+1, *multip-1);
       else
         my_snprintf(str_node, S(str_node), "%s", (xctx->inst[i].node[j])+1 );
     }
     expandlabel(
        get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][j].prop_ptr,"name",0), multip);
     return expandlabel(str_node, &tmp);
   }
   else
   {
     expandlabel(
        get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][j].prop_ptr,"name",0), multip);
     return expandlabel(xctx->inst[i].node[j], &tmp);
   }
 }
}

int isonlydigit(const char *s)
{
  char c;
  int res = 0;
  int first = 1;
  if(s == NULL || *s == '\0') return 0;
  while( (c = *s++) ) {
    if(first == 1) {
      first = 0;
      if(c == '-') {
        continue;
      }
    }
    if(c < '0' || c > '9') {
      res = 0;
      break;
    } else res = 1;
  }
  return res;
}


/* remove leading and trailing characters specified in 'sep' */
char *trim_chars(const char *str, const char *sep)
{
  static char *result = NULL;
  static size_t result_size = 0;
  size_t len;
  char *ptr;
  char *last;

  if(str == NULL) {
    my_free(_ALLOC_ID_, &result);
    result_size = 0;
    return NULL;
  }
  len = strlen(str) + 1;
  /* allocate storage for result */
  if(len > result_size) {
    result_size = len + CADCHUNKALLOC;
    my_realloc(_ALLOC_ID_, &result, result_size);
  }
  memcpy(result, str, len);
  if(*str == '\0')return result;
  ptr = result;
  while (*ptr) {
    if(!strchr(sep, *ptr)) break;
    ptr++;
  }
  if(*ptr == '\0') return ptr;
  last = ptr + strlen(ptr) -1;
  while(strchr(sep, *last) && last > result) {
    last--;
  }
  last[1] = '\0';
  return ptr;
}

/* find nth field in str separated by sep. 1st field is position 1
 * separators inside quotes are not considered as field separators
 * if keep_quote == 1 keep quoting characters  and backslashes in returned field
 * if keep_quote == 4 same as above but remove surrounding "..."
 * find_nth("aaa,bbb,ccc,ddd", ",", 0, 2)  --> bbb
 * find_nth("aaa, \"bbb, \" ccc\" , ddd", " ,", "\"", 0, 2)  --> bbb, " ccc
 * find_nth("aaa, \"bbb, \" ccc\" , ddd", " ,", "\"", 1, 2)  --> "bbb, \" ccc"
 * find_nth("aaa, \"bbb, \" ccc\" , ddd", " ,", "\"", 4, 2)  --> bbb, \" ccc
 */
char *find_nth(const char *str, const char *sep, const char *quote, int keep_quote, int n)
{
  static char *result=NULL; /* safe to keep even with multiple schematic windows */
  static size_t result_size = 0; /* safe to keep even with multiple schematic windows */
  int i, q = 0, e = 0; /* e: escape */
  int result_pos;
  size_t len;
  int count = 0, first_nonsep=1;

  /* clean up static data */
  if(!str) {
    my_free(_ALLOC_ID_, &result);
    result_size = 0;
    return NULL;
  }
  /* allocate storage for result */
  len = strlen(str) + 1;
  if(len > result_size) {
    result_size = len + CADCHUNKALLOC;
    my_realloc(_ALLOC_ID_, &result, result_size);
  }

  result_pos = 0;
  for(i = 0; str[i]; i++) {
    if(!e && strchr(quote, str[i])) {
      q = !q;
      if(keep_quote != 1) {
        continue;
      }
    }
    if(!e && str[i] =='\\') { /* only recognize escape if there are some quoting chars */
      e = 1;
      continue;
    }
    if(!e && !q && strchr(sep, str[i])) {
      first_nonsep = 1;
      if(count == n) { /* first == 1 --> separators at beginning are not preceded by a field */
        break; /* we have found the 'count'th field, return. */
      }
    } else {
      if(first_nonsep) count++; /* found a new field */
      first_nonsep=0;
      if(count == n) {
        if(e == 1 && keep_quote) result[result_pos++] = '\\';
        result[result_pos++] = str[i]; /* if field matches requested one store result */
      }
    }
    e = 0;
  }
  result[result_pos++] = '\0';
  return result;
}

/* given a token like @#pin:attr get value of pin attribute 'attr'
 * if only @#pin is given return name of net attached to 'pin'
 * caller should free returned string */
static char *get_pin_attr(const char *token, int inst, int engineering)
{
  char *value = NULL;
  int n;
  char *pin_attr = NULL;
  char *pin_num_or_name = NULL;

  if(xctx->inst[inst].ptr < 0) return NULL;
  get_pin_and_attr(token, &pin_num_or_name, &pin_attr);
  n = get_inst_pin_number(inst, pin_num_or_name);
  if(n>=0  && pin_attr[0] && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
    char *pin_attr_value = NULL;
    int is_net_name = !strcmp(pin_attr, "net_name");
    /* get pin_attr value from instance: "pinnumber(ENABLE)=5" --> return 5, attr "pinnumber" of pin "ENABLE"
     *                                   "pinnumber(3)=6       --> return 6, attr "pinnumber" of 4th pin */
    if(!is_net_name) {
      pin_attr_value = get_pin_attr_from_inst(inst, n, pin_attr);
      /* get pin_attr from instance pin attribute string */
      if(!pin_attr_value) {
       my_strdup(_ALLOC_ID_, &pin_attr_value,
          get_tok_value(xctx->sym[xctx->inst[inst].ptr].rect[PINLAYER][n].prop_ptr, pin_attr, 0));
      }
    }
    /* @#n:net_name attribute (n = pin number or name) will translate to net name attached  to pin
     * if 'net_name=true' attribute is set in instance or symbol */
    if(!pin_attr_value && is_net_name) {
      prepare_netlist_structs(0);
      my_strdup2(_ALLOC_ID_, &pin_attr_value,
           xctx->inst[inst].node && xctx->inst[inst].node[n] ? xctx->inst[inst].node[n] : "");
    }
    else if(!pin_attr_value && !is_net_name && !strcmp(pin_attr, "spice_get_voltage"))
    {
      int start_level; /* hierarchy level where waves were loaded */
      int live = !raw_is_digital(xctx->raw);
      /* SPEC D5 / RULING D5-5 -- THE `@spice_get_*` FLOATERS ARE THE SCHEMATIC
       * VOLTAGE OVERLAY BY A SECOND ROAD, and they do not go through
       * ngspice::ngspice_data at all: each branch below reads
       * xctx->raw->cursor_b_val[] straight out of the CURRENT database, and
       * draw.c expands these tokens to draw the text that lab_pin, ipin, opin,
       * iopin, vdd, ngspice_probe and scope symbols carry in their T records.
       * So with a digital database current they printed a LOGIC LEVEL as a
       * voltage -- measured `1` on a net whose analog raw reads 0.7535, and
       * `0.5` on a net the VCD says is UNKNOWN (vcd_read()'s VCD_VX encoding):
       * the exact fabricated number RULING D5-1 exists to forbid, on the
       * schematic, in volts, indistinguishable from a measurement.
       *
       * Asking the SINGLE-SOURCED predicate (RULING D5-2), never a local
       * strcmp against "vcd", and asking it at the one precondition all six
       * branches already share -- so a digital database renders these tokens
       * exactly as a session with live backannotation switched off does:
       * NOTHING. "Contributes nothing" is not "contributes a dash"; there is
       * no measurement to report, so no placeholder is invented for one. The
       * Tcl-side overlay says the same thing in its own vocabulary (`?`).
       * The other five sites carry the one-line back-reference.
       *
       * ISSUE 0864 -- `live` USED TO READ THE MENU CHECKBUTTON TOO, and a
       * reader who remembers that will assume the switch still decides what
       * these tokens render. It does not, in any of the six branches. The line
       * was
       *   int live = tclgetboolvar("live_cursor2_backannotate") &&
       *              !raw_is_digital(xctx->raw);
       * and `Simulation > Graphs > Live annotate probes with 'b' cursor` means
       * "follow cursor B and re-annotate as it moves" -- WHEN to re-read, never
       * whether there is anything to read. With it in here, unticking a box
       * about the cursor silently blanked every node voltage and every
       * device-current floater `Alt-6` draws, while the numbers sat untouched
       * in the database. The callers that decide whether to RE-ANNOTATE on
       * cursor motion (callback.c, scheduler.c) still read the switch; that is
       * its whole remaining meaning.
       *
       * WHAT SURVIVES IS THE D5 TERM, and it is not optional: drop
       * !raw_is_digital() and a digital database prints logic levels as volts
       * again. test_backannotate_digital row BA87 is the source witness for all
       * six lines at once -- it counts every `int live = ` line in this file,
       * requires each to carry raw_is_digital, and requires none to name the
       * switch. Its needle is the bare `int live = `, so do not respell these
       * six declarations. */
      if(live && (start_level = sch_waves_loaded()) >= 0 && xctx->raw->annot_p>=0) {
        int multip;
        char *fqnet = NULL;
        const char *path =  xctx->sch_path[xctx->currsch] + 1;
        char *net = NULL;
        int idx;
        double val = 0.0;
        const char *valstr;
        if(path) {
          prepare_netlist_structs(0);
          my_strdup2(_ALLOC_ID_, &net, net_name(inst, n, &multip, 0, 0));
          if(multip == 1 && net && net[0]) {
            char *rn;
            dbg(1, "get_pin_attr() spice_get_voltage: inst=%d\n", inst);
            dbg(1, "                                  net=%s\n", net);
            rn = resolved_net(net);
            if(rn) {
              my_strdup2(_ALLOC_ID_, &fqnet, rn);
              if(rn) my_free(_ALLOC_ID_, &rn);
              strtolower(fqnet);
              dbg(1, "get_pin_attr() @spice_get_voltage: fqnet=%s start_level=%d\n", fqnet, start_level);
              idx = get_raw_index(fqnet, NULL);
              if(idx >= 0) {
                val = xctx->raw->cursor_b_val[idx];
              }
              if(!strcmp(fqnet, "0") || !my_strcasecmp(fqnet, "GND")) valstr = "0.0";
              else if(idx < 0) {
                valstr = "-";
              } else {
                valstr = engineering? dtoa_eng(val, xctx->ev_precision) : dtoa(val);
              }
              my_strdup2(_ALLOC_ID_, &pin_attr_value, valstr);
              dbg(1, "inst %d, net=%s, fqnet=%s idx=%d valstr=%s\n", inst,  net, fqnet, idx, valstr);
              if(fqnet) my_free(_ALLOC_ID_, &fqnet);
            }
          }
          if(net) my_free(_ALLOC_ID_, &net);
        }
      }
    }

    /* @#n:resolved_net attribute (n = pin number or name) will translate to hierarchy-resolved net */
    if(!pin_attr_value && !strcmp(pin_attr, "resolved_net")) {
      char *rn = NULL;
      dbg(1, "translate(): resolved_net: %s, symbol %s\n", xctx->current_name, xctx->inst[inst].name);
      prepare_netlist_structs(0);
      if(xctx->inst[inst].node && xctx->inst[inst].node[n]) {
        rn = resolved_net(xctx->inst[inst].node[n]);
      }
      my_strdup2(_ALLOC_ID_, &pin_attr_value, rn ? rn : "");
      if(rn) my_free(_ALLOC_ID_, &rn);
    }

    if(!pin_attr_value ) my_strdup2(_ALLOC_ID_, &pin_attr_value, "");
    my_strdup2(_ALLOC_ID_, &value, pin_attr_value);
    /* recognize slotted devices: instname = "U3:3", value = "a:b:c:d" --> value = "c" */
    if(pin_attr_value[0] && !strcmp(pin_attr, "pinnumber") ) {
      char *ss;
      int slot;
      char *tmpstr = NULL;
      if( xctx->inst[inst].instname && (ss=strchr(xctx->inst[inst].instname, ':')) ) {
        tmpstr = my_malloc(_ALLOC_ID_, sizeof(xctx->inst[inst].instname));
        sscanf(ss+1, "%s", tmpstr);
        if(isonlydigit(tmpstr)) {
          slot = atoi(tmpstr);
          if(strstr(value,":")) my_strdup2(_ALLOC_ID_, &value, find_nth(value, ":", "", 0, slot));
        }
        my_free(_ALLOC_ID_, &tmpstr);
      }
    }
    my_free(_ALLOC_ID_, &pin_attr_value);
  }
  /* just @#pin was given */
  else if(n>=0  && n < (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER]) {
    const char *str_ptr=NULL;
    int multip;
    size_t tmp;
    prepare_netlist_structs(0);
    str_ptr =  net_name(inst,n, &multip, 0, 1);
    tmp = strlen(str_ptr) +100 ; /* always make room for some extra chars
                                  * so 1-char writes to result do not need reallocs */

    value = my_malloc(_ALLOC_ID_, tmp);
    my_snprintf(value, tmp, "?%d %s ", multip, str_ptr);
  }
  my_free(_ALLOC_ID_, &pin_attr);
  my_free(_ALLOC_ID_, &pin_num_or_name);
  dbg(1, "get_pin_attr(): returning value=%s\n", value);
  return value;
}

/* This routine processes the entire string returned by translate, looks
 * for "@spice_get_node <spice_node> " patterns and replaces with the
 * Spice simulated value for that node.
 * the format is "some_text@spice_get_node <spice_node> some_additional_text"
 * Examples:
 *   Id=@spice_get_node i(\@m.@path@spiceprefix@name\.msky130_fd_pr__@model\[id])
 *     will translate to:
 *   Id=6.6177u
 *   Id=@spice_get_node i(\@m.@path@spiceprefix@name\.msky130_fd_pr__@model\[id]) A
 *     will translate to:
 *   Id=6.6177uA
 * note the required separator spaces around the spice node. Spaces are used here as
 * separators since spice nodes don't allow spaces.
 * escapes are used for 2 reasons:
 * mark a @ as a literal character instead of a the start of a @var token to be substituted
 * mark the end of a @var, like for example @var\iable. In this case @var will
 * be substituted by xschem instead of @variable
 *
 * caveats: only one @spice_get_node is allowed in a string for now.
 */

const char *spice_get_node(const char *token)
{
  const char *pos;

  if((pos = strstr(token, "@spice_get_node "))) {
    char *node = NULL;
    char *token2 = NULL;
    int idx;
    char sp;
    int n;
    size_t len;
    int published;
    double val = 0.0;
    const char *valstr;
    const char *s;

    dbg(1, "token=%s\n", token);
    node = my_malloc(_ALLOC_ID_, strlen(token) + 1);
    n = sscanf(pos, "%*[^ ] %[^ ]%c", node, &sp);
    len = strlen(node);
    dbg(1, "node=%s, n=%d, sp=|%c|\n", node, n, sp);
    /* ISSUE 0861 -- ASK WHETHER ANYTHING WAS PUBLISHED, NOT MERELY WHETHER THE
     * VECTOR EXISTS. cursor_b_val is my_calloc'd, so every entry reads 0.0
     * until update_op() (save.c) or a waveform cursor fills it. update_op()
     * returns early -- an empty database, a non-operating-point run (the 0856
     * refusal, ruled by the user), a digital database -- BEFORE it sets
     * annot_p = 0 and before the fill loop. A reader that tests only the
     * vector index therefore publishes those calloc zeros as if they were
     * measurements: the shipped devices/scope_ammeter.sym painted a confident
     * `0` amps through the branch on a transient the annotation had explicitly
     * declined to answer from, which is precisely the fabricated number
     * RULING D5-1 forbids and the blank INVARIANT I3 requires.
     *
     * WHY annot_p AND NOT THE SIMULATION TYPE. A transient that HAS published,
     * because the user dropped cursor B on a waveform graph, has real values in
     * here and must keep painting them. The question is "was an annotation
     * published", never "what kind of run was it" -- a guard written the second
     * way passes every negative row and silently kills the feature.
     *
     * WHY NOT THE SIX SIBLINGS' FULL SHAPE. The live_cursor2 readers in this
     * file also carry `live && sch_waves_loaded() >= 0`, which folds in the
     * live_cursor2_backannotate switch and demands the current sheet sit inside
     * the waves hierarchy. Those terms are right for a cursor-following
     * annotation and wrong here: they would blank cases that are correct today.
     * annot_p is the minimum term that separates a published value from a
     * calloc zero.
     *
     * The guard must reach the BLANK below, not merely skip the read -- with
     * `val` left at 0.0 the else arm would still print "0".
     *
     * ⚠ tests/headless/test_spice_get_node_0861.tcl row SGN20 greps this
     * function body (C comments stripped first) for an `annot_p` term and for
     * exactly ONE `cursor_b_val` subscript, so the SHAPE of these two lines is
     * pinned by a check, not only their behaviour. */
    published = xctx->raw && xctx->raw->cursor_b_val && xctx->raw->annot_p >= 0;
    idx = get_raw_index(node, NULL);
    if(published && idx >= 0) {
      val = xctx->raw->cursor_b_val[idx];
    }
    if(!strcmp(node, "0") || !my_strcasecmp(node, "GND")) {
      /* ground is a definition, not a measurement: it reads 0.0 in every state,
       * with nothing loaded at all included. This arm stays FIRST and outside
       * the published test on purpose (row SGN16). */
      valstr = "0.0";
    } else if(!published || idx < 0) {
      valstr = "-";
    } else {
      /* always use engineering as these tokens are generated from single
       * @spice_get_node(...) patterns */
      valstr = dtoa_eng(val, xctx->ev_precision);
    }
    dbg(1, "valstr=%s\n", valstr);
    my_strdup2(_ALLOC_ID_, &token2, str_replace(token, "@spice_get_node ", "", 0, 1));
    dbg(1, "token2=%s\n", token2);
    if(n == 2 && sp == ' ') {
      node[len] = ' ';
      node[len + 1] = '\0';
    }
    s = str_replace(token2, node, valstr, 0, 1);
    dbg(1, "s=%s\n", s);
    my_free(_ALLOC_ID_, &token2);
    my_free(_ALLOC_ID_, &node);
    return s;
  } else {
    return token;
  }
}




/* caller must free returned value
 * get the full pathname of "instname" device
 * modelparam:
 *   0: current, 1: modelparam, 2: modelvoltage
 * param: device parameter, like "ib", "gm", "vth"
 * set param to {} (empty str) for just branch current of 2 terminal device
 * for parameters like "vth" modelparam must be 2
 * for parameters like "ib" modelparam must be 0
 * for parameters like "gm" modelparam must be 1
 */
char *get_fqdevice(const char *param, int modelparam, const char *instname)
{
  int start_level; /* hierarchy level where waves were loaded */
  char *fqdev = NULL;
  const char *path =  xctx->sch_path[xctx->currsch] + 1;
  char *dev = NULL;
  size_t len;
  int idx;
  int sim_is_xyce = tcleval("sim_is_xyce")[0] == '1' ? 1 : 0;
  int skip = 0;
  char *iprefix = modelparam == 0 ? "i(" : modelparam == 1 ? "" : "v(";
  char *ipostfix = modelparam == 1 ? "" : ")";
  int prefix;

  start_level = sch_waves_loaded();
  /* skip path components that are above the level where raw file was loaded */
  while(*path && skip < start_level) {
    if(*path == '.') skip++;
    ++path;
  }
  my_strdup2(_ALLOC_ID_, &dev, instname);
  strtolower(dev);
  prefix=dev[0];
  len = strlen(path) + strlen(dev) + 40; /* some extra chars for i(..) wrapper */
  fqdev = my_malloc(_ALLOC_ID_, len);
  if(!sim_is_xyce) {
    int vsource = (prefix == 'v') || (prefix == 'e');
    if(path[0]) {
      if(vsource) {
        my_snprintf(fqdev, len, "i(%c.%s%s)", prefix, path, dev);
      } else if(prefix=='q') {
        my_snprintf(fqdev, len, "%s@%c.%s%s[%s]%s",
                    iprefix, prefix, path, dev, param ? param : "ic", ipostfix);
      } else if(prefix=='d' || prefix == 'm') {
        my_snprintf(fqdev, len, "%s@%c.%s%s[%s]%s",
                    iprefix, prefix, path, dev, param ? param : "id", ipostfix);
      } else if(prefix=='i') {
        my_snprintf(fqdev, len, "i(@%c.%s%s[current])", prefix, path, dev);
      } else {
        my_snprintf(fqdev, len, "i(@%c.%s%s[i])", prefix, path, dev);
      }
    } else {
      if(vsource) {
        my_snprintf(fqdev, len, "i(%s)", dev);
      } else if(prefix == 'q') {
        my_snprintf(fqdev, len, "%s@%s[%s]%s", iprefix, dev, param ? param : "ic", ipostfix);
      } else if(prefix == 'd' || prefix == 'm') {
        my_snprintf(fqdev, len, "%s@%s[%s]%s", iprefix, dev, param ? param : "id", ipostfix);
      } else if(prefix == 'i') {
        my_snprintf(fqdev, len, "i(@%s[current])", dev);
      } else {
        my_snprintf(fqdev, len, "i(@%s[i])", dev);
      }
    }
  } else {
    my_snprintf(fqdev, len, "i(%s%s)", path, dev);
  }
  dbg(1, "fqdev=%s\n", fqdev);
  strtolower(fqdev);
  idx = get_raw_index(fqdev, NULL);
  /* special handling for resistors that are converted to b sources:
   * i(@r.x4.r1[i]) --> i(@b.x4.br1[i])
   */
  if(idx < 0 && !strncmp(fqdev, "i(@r", 4)) {
    if(path[0]) {
      my_snprintf(fqdev, len, "i(@b.%sb%s[i])", path, dev);
    } else {
      my_snprintf(fqdev, len, "i(@b%s[i])", dev);
    }
    dbg(1, "fqdev=%s\n", fqdev);
  }


  my_free(_ALLOC_ID_, &dev);
  return fqdev;

}




/* substitute given tokens in a string with their corresponding values */
/* ex.: name=@name w=@w l=@l ---> name=m112 w=3e-6 l=0.8e-6 */
/* if s==NULL return emty string */
const char *translate(int inst, const char* s)
{
  #ifdef __unix__
  static regex_t *get_sp_cur = NULL;
  #endif
  static const char *empty="";
  static char *result=NULL; /* safe to keep even with multiple schematics */
  size_t size=0;
  size_t tmp;
  register int c, state=TOK_BEGIN, space;
  char *token=NULL;
  const char *tmp_sym_name;
  size_t sizetok=0;
  size_t result_pos=0, token_pos=0;
  struct stat time_buf;
  struct tm *tm;
  char file_name[PATH_MAX];
  const char *value;
  int escape=0, engineering = 0;
  char date[200];
  int sp_prefix;
  int level;
  Lcc *lcc;
  char *value1 = NULL;
  int sim_is_ngspice, sim_is_vacask /*, sim_is_xyce */;
  char *instname = NULL;

  if(!s && inst == -1) {
    if(result) my_free(_ALLOC_ID_, &result);
    #ifdef __unix__
    if(get_sp_cur) {
      regfree(get_sp_cur);
      /* get_sp_cur = NULL; */
      my_free(_ALLOC_ID_, &get_sp_cur);
    }
    #endif
  }

  if(!s || !xctx || !xctx->inst) {
    return empty;
  }

  #ifdef __unix__
  if(!get_sp_cur) {
    get_sp_cur = my_malloc(_ALLOC_ID_, sizeof(regex_t));
    /* @spice_get_current_<param>(...) or @spice_get_modelparam_<param>(...) */
    /* @spice_get_current(...) or @spice_get_modelparam(...) */
    /* @spice_get_modelvoltage(...) or @spice_get_modelvoltage_<param>(...) */
    regcomp(get_sp_cur,
        "^@spice_get_(current|modelparam|modelvoltage)(_[a-zA-Z][a-zA-Z0-9_]*)*\\(", REG_NOSUB | REG_EXTENDED);
  }
  #endif

  sp_prefix = tclgetboolvar("spiceprefix");

  if(inst >= xctx->instances) {
    dbg(0, "translate(): instance number out of bounds: %d\n", inst);
    return empty;
  }
  /* if spice_get_* token not processed by tcl use enginering notation (2m, 3u, ...)  */
  if(!(strstr(s, "tcleval(") == s)) engineering = 1;
  instname = (inst >=0 && xctx->inst[inst].instname) ? xctx->inst[inst].instname : "";
  sim_is_ngspice = tcleval("sim_is_ngspice")[0] == '1' ? 1 : 0;
  sim_is_vacask = tcleval("sim_is_vacask")[0] == '1' ? 1 : 0;
  /* sim_is_xyce = tcleval("sim_is_xyce")[0] == '1' ? 1 : 0; */
  level = xctx->currsch;
  lcc = xctx->hier_attr;
  size=CADCHUNKALLOC;
  my_realloc(_ALLOC_ID_, &result,size);
  result[0]='\0';

  dbg(1, "translate(): substituting props in <%s>, instance <%s>\n", s ? s : "<NULL>" , instname);

  while(1)
  {
    c=*s++;
    if(c=='\\') {
      escape=1;
      c=*s++; /* do not remove: breaks translation of format strings in netlists (escaping %) */
    }
    else escape=0;
    space=SPACE(c);
    if( state==TOK_BEGIN && (c=='@' || c=='%' ) && !escape  ) state=TOK_TOKEN; /* 20161210 escape */
    else if(state==TOK_TOKEN && token_pos > 1 &&
       (
         ( (space  || c == '%' || c == '@') && !escape ) ||
         ( (!space && c != '%' && c != '@') && escape  )
       )
      ) state=TOK_SEP;

    STR_ALLOC(&result, result_pos, &size);
    STR_ALLOC(&token, token_pos, &sizetok);
    if(state==TOK_TOKEN) token[token_pos++]=(char)c;
    else if(state==TOK_SEP)
    {
      token[token_pos]='\0';
      if(!strcmp(token, "@name")) {
        tmp = strlen(instname);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos, instname, tmp+1);
        result_pos+=tmp;
      } else if(inst >= 0 && strcmp(token,"@symref")==0) {
       tmp_sym_name = get_sym_name(inst, 9999, 1, 0);
       tmp_sym_name=tmp_sym_name ? tmp_sym_name : "";
       tmp=strlen(tmp_sym_name);
       STR_ALLOC(&result, tmp + result_pos, &size);
       memcpy(result+result_pos,tmp_sym_name, tmp+1);
       result_pos+=tmp;
      } else if(inst >= 0 && strcmp(token,"@lvs_ignore")==0) {
       char *lvs = tclgetboolvar("lvs_ignore") ? "1" : "0";
       tmp = strlen(lvs);
       STR_ALLOC(&result, tmp + result_pos, &size);
       memcpy(result+result_pos, lvs, tmp+1);
       result_pos+=tmp;
      } else if(inst >= 0 && strcmp(token,"@symname")==0) {
       tmp_sym_name = get_sym_name(inst, 0, 0, 0);
       tmp_sym_name=tmp_sym_name ? tmp_sym_name : "";
       tmp=strlen(tmp_sym_name);
       STR_ALLOC(&result, tmp + result_pos, &size);
       memcpy(result+result_pos,tmp_sym_name, tmp+1);
       result_pos+=tmp;
      } else if(strcmp(token,"@path")==0) {
       const char *path = xctx->sch_path[xctx->currsch] + 1;
       int start_level = sch_waves_loaded(), skip = 0;
       if(start_level == -1) start_level = 0;

       /* skip path components that are above the level where raw file was loaded */
       while(*path && skip < start_level) {
         if(*path == '.') skip++;
         ++path;
       }

       tmp=strlen(path);
       STR_ALLOC(&result, tmp + result_pos, &size);
       memcpy(result+result_pos, path, tmp+1);
       result_pos+=tmp;
      } else if(inst >= 0 && strcmp(token,"@symname_ext")==0) {
       tmp_sym_name = get_sym_name(inst, 0, 1, 0);
       tmp_sym_name=tmp_sym_name ? tmp_sym_name : "";
       tmp=strlen(tmp_sym_name);
       STR_ALLOC(&result, tmp + result_pos, &size);
       memcpy(result+result_pos,tmp_sym_name, tmp+1);
       result_pos+=tmp;
      /* recognize single pins 15112003 */
      } else if(inst >= 0 && token[0]=='@' && token[1]=='@' && xctx->inst[inst].ptr >= 0) {
        int i, multip;
        int no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
        prepare_netlist_structs(0);
        for(i=0;i<no_of_pins; ++i) {
          char *prop = (xctx->inst[inst].ptr + xctx->sym)->rect[PINLAYER][i].prop_ptr;
          if (!strcmp( get_tok_value(prop,"name",0), token+2)) {
            if(strboolcmp(get_tok_value(prop,"spice_ignore",0), "true")) {
              const char *str_ptr =  net_name(inst,i, &multip, 0, 0);
              tmp = strlen(str_ptr) +100 ;
              STR_ALLOC(&result, tmp + result_pos, &size);
              result_pos += my_snprintf(result + result_pos, tmp, "%s", str_ptr);
            }
            break;
          }
        }
      } else if(inst >= 0 && token[0]=='@' && token[1]=='#') {
        value = get_pin_attr(token, inst, engineering);
        if(value) {
          tmp=strlen(value);
          STR_ALLOC(&result, tmp + result_pos, &size);
          memcpy(result+result_pos, value, tmp+1);
          result_pos+=tmp;
          my_free(_ALLOC_ID_, &value);
        }
      } else if(inst >= 0 && strcmp(token,"@sch_last_modified")==0 && xctx->inst[inst].ptr >= 0) {

       get_sch_from_sym(file_name, xctx->inst[inst].ptr + xctx->sym, inst, 0);
       if(!stat(file_name , &time_buf)) {
         tm=localtime(&(time_buf.st_mtime) );
         tmp=strftime(date, sizeof(date), "%Y-%m-%d  %H:%M:%S", tm);
         STR_ALLOC(&result, tmp + result_pos, &size);
         memcpy(result+result_pos, date, tmp+1);
         result_pos+=tmp;
       }
      } else if(inst >= 0 && strcmp(token,"@sym_last_modified")==0) {
       my_strncpy(file_name, abs_sym_path(tcl_hook2(xctx->inst[inst].name), ""), S(file_name));
       if(!stat(file_name , &time_buf)) {
         tm=localtime(&(time_buf.st_mtime) );
         tmp=strftime(date, sizeof(date), "%Y-%m-%d  %H:%M:%S", tm);
         STR_ALLOC(&result, tmp + result_pos, &size);
         memcpy(result+result_pos, date, tmp+1);
         result_pos+=tmp;
       }
      } else if(strcmp(token,"@time_last_modified")==0) {
       my_strncpy(file_name, abs_sym_path(xctx->sch[xctx->currsch], ""), S(file_name));
       if(!stat(file_name , &time_buf)) {
         tm=localtime(&(time_buf.st_mtime) );
         tmp=strftime(date, sizeof(date), "%Y-%m-%d  %H:%M:%S", tm);
         STR_ALLOC(&result, tmp + result_pos, &size);
         memcpy(result+result_pos, date, tmp+1);
         result_pos+=tmp;
       }
      } else if(strcmp(token,"@schname_ext")==0) {
        /* tmp=strlen(xctx->sch[xctx->currsch]);*/
        tmp = strlen(xctx->current_name);
        STR_ALLOC(&result, tmp + result_pos, &size);
        /* memcpy(result+result_pos,xctx->sch[xctx->currsch], tmp+1); */
        memcpy(result+result_pos, xctx->current_name, tmp+1);
        result_pos+=tmp;
      } else if(strcmp(token,"@schname")==0) {
        const char *schname = get_cell(xctx->current_name, 0);
        tmp = strlen(schname);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos, schname, tmp+1);
        result_pos+=tmp;
      } else if(strcmp(token,"@topschname")==0)  {
         const char *topsch;
         topsch = get_trailing_path(xctx->sch[0], 0, 1);
         tmp = strlen(topsch);
         STR_ALLOC(&result, tmp + result_pos, &size);
         memcpy(result+result_pos, topsch, tmp+1);
         result_pos+=tmp;
      } else if(inst >= 0 && strcmp(token,"@prop_ptr")==0 && xctx->inst[inst].prop_ptr) {
        tmp=strlen(xctx->inst[inst].prop_ptr);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos,xctx->inst[inst].prop_ptr, tmp+1);
        result_pos+=tmp;
      }
      else if(inst >= 0 && strcmp(token,"@spice_get_voltage")==0 && xctx->inst[inst].ptr >= 0)
      {
        int start_level; /* hierarchy level where waves were loaded */
        int live = !raw_is_digital(xctx->raw);
        /* the D5 guard -- see the long note at the first `@spice_get_voltage`
         * branch in get_pin_attr() above: a digital database contributes
         * NOTHING to the schematic overlay, floaters included. */
        if(live && (start_level = sch_waves_loaded()) >= 0 && xctx->raw->annot_p>=0) {
          int multip;
          int no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
          if(no_of_pins == 1) {
            char *fqnet = NULL;
            const char *path =  xctx->sch_path[xctx->currsch] + 1;
            char *net = NULL;
            size_t len;
            int idx;
            double val = 0.0;
            const char *valstr;
            if(path) {
              prepare_netlist_structs(0);
              if(xctx->inst[inst].lab) {
                my_strdup2(_ALLOC_ID_, &net, expandlabel(xctx->inst[inst].lab, &multip));
              }
              if(net == NULL || net[0] == '\0') {
                my_strdup2(_ALLOC_ID_, &net, net_name(inst, 0, &multip, 0, 0));
              }
              if(multip == 1 && net && net[0]) {
                char *rn;
                dbg(1, "translate() @spice_get_voltage: inst=%s\n", instname);
                dbg(1, "                                net=%s\n", net);
                rn = resolved_net(net);
                if(rn) {
                  my_strdup2(_ALLOC_ID_, &fqnet, rn);
                  if(rn) my_free(_ALLOC_ID_, &rn);
                  strtolower(fqnet);
                  dbg(1, "translate() @spice_get_voltage: fqnet=%s start_level=%d\n", fqnet, start_level);
                  idx = get_raw_index(fqnet, NULL);
                  if(idx >= 0) {
                    val = xctx->raw->cursor_b_val[idx];
                  }
                  if(!strcmp(fqnet, "0") || !my_strcasecmp(fqnet, "GND")) {
                    valstr = "0.0";
                    xctx->tok_size = 3;
                    len = 3;
                  } else if(idx < 0) {
                    valstr = "-";
                    xctx->tok_size = 5;
                    len = 5;
                  } else {
                    valstr = engineering ? dtoa_eng(val, xctx->ev_precision) : dtoa(val);
                    len = xctx->tok_size;
                  }
                  if(len) {
                    STR_ALLOC(&result, len + result_pos, &size);
                    memcpy(result+result_pos, valstr, len+1);
                    result_pos += len;
                  }
                  dbg(1, "inst %d, net=%s, fqnet=%s idx=%d valstr=%s\n", inst,  net, fqnet, idx, valstr);
                  if(fqnet) my_free(_ALLOC_ID_, &fqnet);
                }
              }
              if(net) my_free(_ALLOC_ID_, &net);
            }
          }
        }
      }

      /* copy as is: processed by spice_get_node() later
       * the format is "some_text@spice_get_node <spice_node> some_additional_text"
       * Examples:
       *   Id=@spice_get_node i(\@m.@path@spiceprefix@name\.msky130_fd_pr__@model\[id])
       *     will translate to:
       *   Id=6.6177u
       *   Id=@spice_get_node i(\@m.@path@spiceprefix@name\.msky130_fd_pr__@model\[id]) A
       *     will translate to:
       *   Id=6.6177uA
       * note the required separator spaces around the spice node. Spaces are used here as
       * separators since spice nodes don't allow spaces.
       * escapes are used for 2 reasons:
       * mark a @ as a literal character instead of a the start of a @var token to be substituted
       * mark the end of a @var, like for example @var\iable. In this case @var will
       * be substituted by xschem instead of @variable
       *
       * caveats: only one @spice_get_node is allowed in a string
       */
      else if(strcmp(token,"@spice_get_node")==0 )
      {
        STR_ALLOC(&result, 15 + result_pos, &size);
        memcpy(result+result_pos, token, 16);
        result_pos += 15;
      }
      else if(strncmp(token,"@spice_get_voltage(", 19)==0 )
      {
        int start_level; /* hierarchy level where waves were loaded */
        int live = !raw_is_digital(xctx->raw);
        /* the D5 guard -- see the long note at the first `@spice_get_voltage`
         * branch in get_pin_attr() above: a digital database contributes
         * NOTHING to the schematic overlay, floaters included. */
        dbg(1, "--> %s\n", token);
        if(live && (start_level = sch_waves_loaded()) >= 0 && xctx->raw->annot_p>=0) {
          char *fqnet = NULL;
          const char *path =  xctx->sch_path[xctx->currsch] + 1;
          char *net = NULL;
          char *global_net;
          size_t len;
          int idx, n, multip;
          double val = 0.0;
          const char *valstr;
          tmp = strlen(token) + 1;
          if(path) {
            int skip = 0;
            /* skip path components that are above the level where raw file was loaded */
            while(*path && skip < start_level) {
              if(*path == '.') skip++;
              ++path;
            }
            net = my_malloc(_ALLOC_ID_, tmp);
            n = sscanf(token + 19, "%[^)]", net);
            expandlabel(net, &multip);
            if(n == 1 && multip == 1) {
              len = strlen(path) + strlen(instname) + strlen(net) + 2;
              dbg(1, "net=%s\n", net);
              fqnet = my_malloc(_ALLOC_ID_, len);


              global_net = strrchr(net, '.');
              if(global_net == NULL) global_net = net;
              else global_net++;

              if(inst < 0 || record_global_node(3, NULL, global_net)) {
                strtolower(net);
                my_snprintf(fqnet, len, "%s", global_net);
              } else {
                strtolower(net);
                my_snprintf(fqnet, len, "%s%s.%s", path, instname, net);
              }
              strtolower(fqnet);
              dbg(1, "translate(): inst=%d, net=%s, fqnet=%s start_level=%d\n", inst, net, fqnet, start_level);
              idx = get_raw_index(fqnet, NULL);
              if(idx >= 0) {
                val = xctx->raw->cursor_b_val[idx];
              }
              if(!strcmp(fqnet, "0") || !my_strcasecmp(fqnet, "GND")) {
                valstr = "0.0";
                xctx->tok_size = 3;
                len = 3;
              } else if(idx < 0) {
                valstr = "-";
                xctx->tok_size = 1;
                len = 1;
              } else {
                /* always use engineering as these tokens are generated from single
                 * @spice_get_voltage patterns */
                valstr = dtoa_eng(val, xctx->ev_precision);
                len = xctx->tok_size;
              }
              if(len) {
                STR_ALLOC(&result, len + result_pos, &size);
                memcpy(result+result_pos, valstr, len+1);
                result_pos += len;
              }
              dbg(1, "instname %s, net=%s, fqnet=%s idx=%d valstr=%s\n", instname,  net, fqnet, idx, valstr);
              my_free(_ALLOC_ID_, &fqnet);
            }
            my_free(_ALLOC_ID_, &net);
          }
        }
      }
      /* @spice_get_current(...) or @spice_get_current_<param>(...)
       * @spice_get_modelparam(...) or @spice_get_modelparam_<param>(...)
       * @spice_get_modelvoltage(...) or @spice_get_modelvoltage_<param>(...)
       *
       * Only @spice_get_current(...) and @spice_get_current_<param>(...) are processed
       * the other types are ignored */
      #ifdef __unix__
      else if(!regexec(get_sp_cur, token, 0 , NULL, 0) )
      # else
      else if ((win_regexec(NULL/*options*/, "^@spice_get_(current|modelparam|modelvoltage)(_[a-zA-Z][a-zA-Z0-9_]*)*\\(", token)))
      #endif
      {
        int start_level; /* hierarchy level where waves were loaded */
        int live = !raw_is_digital(xctx->raw);
        /* the D5 guard -- see the long note at the first `@spice_get_voltage`
         * branch in get_pin_attr() above: a digital database contributes
         * NOTHING to the schematic overlay, floaters included. */
        if(live && (start_level = sch_waves_loaded()) >= 0 && xctx->raw->annot_p>=0) {
          char *fqdev = NULL;
          const char *path =  xctx->sch_path[xctx->currsch] + 1;
          char *dev = NULL, *param = NULL;
          size_t len;
          int idx, n = 0;
          double val = 0.0;
          const char *valstr;
          tmp = strlen(token) + 1;
          if(path) {
            int skip = 0;
            /* skip path components that are above the level where raw file was loaded */
            while(*path && skip < start_level) {
              if(*path == '.') skip++;
              ++path;
            }
            dev = my_malloc(_ALLOC_ID_, tmp);
            dbg(1, "%s\n", token);
            if(!strncmp(token, "@spice_get_current(", 19)) {
              n = sscanf(token + 19, "%[^)]", dev);
            } else {
              param = my_malloc(_ALLOC_ID_, tmp);
              n = sscanf(token, "@spice_get_current_%[^(](%[^)]", param, dev);
              dbg(1, "token=%s, param=%s, dev=%s\n", token, param, dev);
              if(n < 2) {
                my_free(_ALLOC_ID_, &param);
                n = sscanf(token, "@spice_get_current[^(](%[^)]", dev);
              }
            }
            if(n >= 1) {
              strtolower(dev);
              len = strlen(path) + strlen(instname) +
                    strlen(dev) + 21; /* some extra chars for i(..) wrapper */
              dbg(1, "dev=%s\n", dev);
              fqdev = my_malloc(_ALLOC_ID_, len);
              if(sim_is_ngspice) {
                int prefix, vsource;
                char *prefix_ptr = strrchr(dev, '.'); /* last '.' in dev */
                if(prefix_ptr) prefix = prefix_ptr[1]; /* character after last '.' */
                else prefix=dev[0];
                dbg(1, "prefix=%c, path=%s\n", prefix, path);
                vsource = (prefix == 'v') || (prefix == 'e');
                if(vsource) {
                  my_snprintf(fqdev, len, "i(%c.%s%s.%s)", prefix, path, instname, dev);
                } else if(prefix == 'q') {
                  my_snprintf(fqdev, len, "i(@%c.%s%s.%s[%s])", prefix, path, instname, dev, param ? param : "ic");
                } else if(prefix == 'd' || prefix == 'm') {
                  my_snprintf(fqdev, len, "i(@%c.%s%s.%s[%s])", prefix, path, instname, dev, param ? param : "id");
                  dbg(1, "translate(): fqdev=%s\n", fqdev);
                } else if(prefix == 'i') {
                  my_snprintf(fqdev, len, "i(@%c.%s%s.%s[current])", prefix, path, instname, dev);
                } else {
                 my_snprintf(fqdev, len, "i(@%c.%s%s.%s[i])", prefix, path, instname, dev);
                }
              } else if(sim_is_vacask) {
                my_snprintf(fqdev, len, "%s%s.flow(br)", path, instname);
              } else { /*xyce */
                my_snprintf(fqdev, len, "i(%s%s.%s)", path, instname, dev);
              }
              strtolower(fqdev);
              dbg(1, "fqdev=%s\n", fqdev);
              idx = get_raw_index(fqdev, NULL);
              if(idx >= 0) {
                val = xctx->raw->cursor_b_val[idx];
              }
              if(idx < 0) {
                valstr = "-";
                xctx->tok_size = 1;
                len = 1;
              } else {
                /* always use engineering as these tokens are generated from single
                 * @spice_get_voltage patterns */
                valstr = dtoa_eng(val, xctx->ev_precision);
                len = xctx->tok_size;
              }
              if(len) {
                STR_ALLOC(&result, len + result_pos, &size);
                memcpy(result+result_pos, valstr, len+1);
                result_pos += len;
              }
              dbg(1, "instname %s, dev=%s, fqdev=%s idx=%d valstr=%s\n", instname,  dev, fqdev, idx, valstr);
              my_free(_ALLOC_ID_, &fqdev);
            } /* if(n == 1) */
            if(param) my_free(_ALLOC_ID_, &param);
            my_free(_ALLOC_ID_, &dev);
          } /* if(path) */
        } /* if((start_level = sch_waves_loaded()) >= 0 && xctx->raw->annot_p>=0) */
      }
      else if(inst >= 0 && strcmp(token,"@spice_get_diff_voltage")==0  && xctx->inst[inst].ptr >= 0)
      {
        int start_level; /* hierarchy level where waves were loaded */
        int live = !raw_is_digital(xctx->raw);
        /* the D5 guard -- see the long note at the first `@spice_get_voltage`
         * branch in get_pin_attr() above: a digital database contributes
         * NOTHING to the schematic overlay, floaters included. */
        if(live && (start_level = sch_waves_loaded()) >= 0 && xctx->raw->annot_p>=0) {
          int multip;
          int no_of_pins= (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
          if(no_of_pins == 2) {
            char *fqnet1 = NULL, *fqnet2 = NULL;
            const char *path =  xctx->sch_path[xctx->currsch] + 1;
            const char *net1, *net2;
            size_t len;
            int idx1, idx2;
            double val = 0.0, val1 = 0.0, val2 = 0.0;
            const char *valstr;
            if(path) {
              int gnd1 = 0, gnd2 = 0;
              int skip = 0;
              /* skip path components that are above the level where raw file was loaded */
              while(*path && skip < start_level) {
                if(*path == '.') skip++;
                ++path;
              }
              prepare_netlist_structs(0);
              net1 = net_name(inst, 0, &multip, 0, 0);
              len = strlen(path) + strlen(net1) + 1;
              dbg(1, "net1=%s\n", net1);
              fqnet1 = my_malloc(_ALLOC_ID_, len);
              my_snprintf(fqnet1, len, "%s%s", path, net1);
              strtolower(fqnet1);
              net2 = net_name(inst, 1, &multip, 0, 0);
              len = strlen(path) + strlen(net2) + 1;
              dbg(1, "net2=%s\n", net2);
              fqnet2 = my_malloc(_ALLOC_ID_, len);
              my_snprintf(fqnet2, len, "%s%s", path, net2);
              strtolower(fqnet2);
              dbg(1, "translate(): fqnet1=%s start_level=%d\n", fqnet1, start_level);
              dbg(1, "translate(): fqnet2=%s start_level=%d\n", fqnet2, start_level);
              if(!strcmp(fqnet1, "0") || !my_strcasecmp(fqnet1, "GND")) gnd1 = 1;
              if(!strcmp(fqnet2, "0") || !my_strcasecmp(fqnet2, "GND")) gnd2 = 1;
              idx1 = get_raw_index(fqnet1, NULL);
              idx2 = get_raw_index(fqnet2, NULL);
              if( (!gnd1 && idx1 < 0) || (!gnd2 && idx2 < 0) ) {
                valstr = "-";
                xctx->tok_size = 1;
                len = 1;
              } else {
                double val1 = gnd1 ? 0.0 : xctx->raw->cursor_b_val[idx1];
                double val2 = gnd2 ? 0.0 : xctx->raw->cursor_b_val[idx2];
                val = val1 - val2;
                valstr = engineering ? dtoa_eng(val, xctx->ev_precision) : dtoa(val);
                len = xctx->tok_size;
              }
              if(len) {
                STR_ALLOC(&result, len + result_pos, &size);
                memcpy(result+result_pos, valstr, len+1);
                result_pos += len;
              }
              dbg(1, "inst %d, fqnet1=%s fqnet2=%s idx1=%d idx2=%d, val1=%g val2=%g valstr=%s\n",
                  inst, fqnet1, fqnet2, idx1, idx2, val1, val2, valstr);
              my_free(_ALLOC_ID_, &fqnet1);
              my_free(_ALLOC_ID_, &fqnet2);
            }
          }
        }
      }
      else if(
               strncmp(token,"@spice_get_current", 18)==0 ||
               strncmp(token,"@spice_get_modelparam", 21)==0 ||
               strncmp(token,"@spice_get_modelvoltage", 23)==0
             )
      {
        int start_level; /* hierarchy level where waves were loaded */
        int live = !raw_is_digital(xctx->raw);
        /* the D5 guard -- see the long note at the first `@spice_get_voltage`
         * branch in get_pin_attr() above: a digital database contributes
         * NOTHING to the schematic overlay, floaters included. */
        if(live && (start_level = sch_waves_loaded()) >= 0 && xctx->raw->annot_p>=0) {
          char *fqdev = NULL;
          const char *path =  xctx->sch_path[xctx->currsch] + 1;
          char *dev = NULL, *param = NULL;
          int modelparam = 0; /* 0: current, 1: modelparam, 2: modelvoltage */
          size_t len;
          int idx;
          int error = 0;
          double val = 0.0;
          const char *valstr;
          if(path) {
            int skip = 0;
            /* skip path components that are above the level where raw file was loaded */
            while(*path && skip < start_level) {
              if(*path == '.') skip++;
              ++path;
            }
            /* token contans _param after @spice_get_current or @spice_get_modelparam
             * or  @spice_get_modelvoltage */
            if(strcmp(token, "@spice_get_current") &&
               strcmp(token, "@spice_get_modelparam") &&
               strcmp(token, "@spice_get_modelvoltage")) {
              int n = 0;
              param = my_malloc(_ALLOC_ID_, strlen(token) + 1);
              n = sscanf(token, "@spice_get_current_%s", param);
              if(n == 0) {
                n = sscanf(token, "@spice_get_modelparam_%s", param);
                modelparam = 1;
              }
              if(n == 0) {
                n = sscanf(token, "@spice_get_modelvoltage_%s", param);
                modelparam = 2;
              }
              if(n == 0) {
                my_free(_ALLOC_ID_, &param);
                error = 1;
              }
            }
            if(!error) {
              char *iprefix = modelparam == 0 ? "i(" : modelparam == 1 ? "" : "v(";
              char *ipostfix = modelparam == 1 ? "" : ")";
              int prefix;
              my_strdup2(_ALLOC_ID_, &dev, instname);
              strtolower(dev);
              prefix=dev[0];
              len = strlen(path) + strlen(dev) + 40; /* some extra chars for i(..) wrapper */
              dbg(1, "token=%s, dev=%s param=%s\n", token, dev, param ? param : "<NULL>");
              fqdev = my_malloc(_ALLOC_ID_, len);
              if(sim_is_ngspice) {
                int vsource = (prefix == 'v') || (prefix == 'e');
                if(path[0]) {
                  if(vsource) {
                    my_snprintf(fqdev, len, "i(%c.%s%s)", prefix, path, dev);
                  } else if(prefix=='q') {
                    my_snprintf(fqdev, len, "%s@%c.%s%s[%s]%s",
                                iprefix, prefix, path, dev, param ? param : "ic", ipostfix);
                  } else if(prefix=='d' || prefix == 'm') {
                    my_snprintf(fqdev, len, "%s@%c.%s%s[%s]%s",
                                iprefix, prefix, path, dev, param ? param : "id", ipostfix);
                  } else if(prefix=='i') {
                    my_snprintf(fqdev, len, "i(@%c.%s%s[current])", prefix, path, dev);
                  } else {
                    my_snprintf(fqdev, len, "i(@%c.%s%s[i])", prefix, path, dev);
                  }
                } else {
                  if(vsource) {
                    my_snprintf(fqdev, len, "i(%s)", dev);
                  } else if(prefix == 'q') {
                    my_snprintf(fqdev, len, "%s@%s[%s]%s", iprefix, dev, param ? param : "ic", ipostfix);
                  } else if(prefix == 'd' || prefix == 'm') {
                    my_snprintf(fqdev, len, "%s@%s[%s]%s", iprefix, dev, param ? param : "id", ipostfix);
                  } else if(prefix == 'i') {
                    my_snprintf(fqdev, len, "i(@%s[current])", dev);
                  } else {
                    my_snprintf(fqdev, len, "i(@%s[i])", dev);
                  }
                }
              } else if(sim_is_vacask) {
                my_snprintf(fqdev, len, "%s%s.flow(br)", path, instname);
              } else { /*xyce */
                my_snprintf(fqdev, len, "i(%s%s)", path, dev);
              }
              if(param) my_free(_ALLOC_ID_, &param);
              dbg(1, "fqdev=%s\n", fqdev);
              strtolower(fqdev);
              idx = get_raw_index(fqdev, NULL);
              if(idx >= 0) {
                val = xctx->raw->cursor_b_val[idx];
              }
              /* special handling for resistors that are converted to b sources:
               * i(@r.x4.r1[i]) --> i(@b.x4.br1[i])
               */
              if(idx < 0 && !strncmp(fqdev, "i(@r", 4)) {
                if(path[0]) {
                  my_snprintf(fqdev, len, "i(@b.%sb%s[i])", path, dev);
                } else {
                  my_snprintf(fqdev, len, "i(@b%s[i])", dev);
                }
                dbg(1, "fqdev=%s\n", fqdev);
                idx = get_raw_index(fqdev, NULL);
                if(idx >= 0) {
                  val = xctx->raw->cursor_b_val[idx];
                }
              }
              if(idx < 0) {
                valstr = "-";
                xctx->tok_size = 1;
                len = 1;
              } else {
                valstr = engineering ? dtoa_eng(val, xctx->ev_precision) : dtoa(val);
                len = xctx->tok_size;
              }
              if(len) {
                STR_ALLOC(&result, len + result_pos, &size);
                memcpy(result+result_pos, valstr, len+1);
                result_pos += len;
              }
              dbg(1, "instname %s, dev=%s, fqdev=%s idx=%d valstr=%s\n", instname,  dev, fqdev, idx, valstr);
              my_free(_ALLOC_ID_, &fqdev);
              my_free(_ALLOC_ID_, &dev);
            } /* if(!error) */
          } /* if(path) */
        } /* (live && (start_level = sch_waves_loaded()) >= 0 && xctx->raw->annot_p>=0) */
      }
      else if(strcmp(token,"@schvhdlprop")==0 && xctx->schvhdlprop)
      {
        tmp=strlen(xctx->schvhdlprop);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos,xctx->schvhdlprop, tmp+1);
        result_pos+=tmp;
      }

      else if(strcmp(token,"@schspectreprop")==0 && xctx->schspectreprop)
      {
        tmp=strlen(xctx->schspectreprop);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos,xctx->schspectreprop, tmp+1);
        result_pos+=tmp;
      }

      else if(strcmp(token,"@schprop")==0 && xctx->schprop)
      {
        tmp=strlen(xctx->schprop);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos,xctx->schprop, tmp+1);
        result_pos+=tmp;
      }
      /* /20100217 */

      else if(strcmp(token,"@schsymbolprop")==0 && xctx->schsymbolprop)
      {
        tmp=strlen(xctx->schsymbolprop);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos,xctx->schsymbolprop, tmp+1);
        result_pos+=tmp;
      }

      else if(strcmp(token,"@schtedaxprop")==0 && xctx->schtedaxprop)
      {
        tmp=strlen(xctx->schtedaxprop);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos,xctx->schtedaxprop, tmp+1);
        result_pos+=tmp;
      }
      /* /20100217 */

      else if(strcmp(token,"@schverilogprop")==0 && xctx->schverilogprop)
      {
        tmp=strlen(xctx->schverilogprop);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos,xctx->schverilogprop, tmp+1);
        result_pos+=tmp;
      /* if spiceprefix==0 and token == @spiceprefix then set empty value */
      } else if(!sp_prefix && !strcmp(token, "@spiceprefix")) {
        /* add nothing */
      } else {
        if(inst >= 0) {
          value = get_tok_value(xctx->inst[inst].prop_ptr, token+1, 0);
          if(!xctx->tok_size && xctx->inst[inst].ptr >= 0) {
            value=get_tok_value(xctx->sym[xctx->inst[inst].ptr].templ, token+1, 0);
          }
        } else {
          xctx->tok_size = 1;
          value = token + 1;
        }
        if(!xctx->tok_size) { /* above lines did not find a value for token */
          if(token[0] =='%') {
            /* no definition found -> subst with token without leading % */
            tmp=token_pos -1 ; /* we need token_pos -1 chars, ( strlen(token+1) ) , excluding leading '%' */
            STR_ALLOC(&result, tmp + result_pos, &size);
            /* dbg(2, "translate(): token=%s, token_pos = %d\n", token, token_pos); */
            memcpy(result+result_pos, token + 1, tmp+1);
            result_pos+=tmp;
          }
        } else {
          int i = level;
          char *schname_attr = NULL; 
          my_mstrcat(_ALLOC_ID_, &schname_attr, "schname=\"", get_cell(xctx->current_name, 0), "\"", NULL);
          my_strdup2(_ALLOC_ID_, &value1, value);
          /* recursive substitution of value using parent level prop_ptr attributes */
          while(i > 0) {
            char *v = value1;
            const char *tok;
            if(v && v[0] == '@') v++;
            tok = get_tok_value(lcc[i-1].prop_ptr, v, 0);
            if(xctx->tok_size && tok[0]) {
              dbg(1, "tok=%s\n", tok);
              my_strdup2(_ALLOC_ID_, &value1, tok);
            } else {
              tok = get_tok_value(lcc[i-1].templ,  v, 0);
              if(xctx->tok_size && tok[0]) {
                dbg(1, "from parent template: tok=%s\n", tok);
                my_strdup2(_ALLOC_ID_, &value1, tok);
              }
            }
            dbg(1, "2 translate(): lcc[%d].prop_ptr=%s, value1=%s\n", i-1, lcc[i-1].prop_ptr, value1);
            i--;
          }
          if(strchr(value1, '@')) {
            my_strdup(_ALLOC_ID_, &value1, translate3(value1, 1, schname_attr, NULL, NULL, NULL));
          }
          /* substitute remaing @params */
          i = level;
          while(i > 0) {
            if(strchr(value1, '@')) {
              my_strdup(_ALLOC_ID_, &value1, translate3(value1, 1, lcc[i-1].prop_ptr, NULL, NULL, NULL));
              dbg(1, "2 translate(): lcc[%d].prop_ptr=%s, value1=%s\n", i-1, lcc[i-1].prop_ptr, value1);
            } else break;
            i--;
          }
          my_free(_ALLOC_ID_, &schname_attr);
          /* substitute remaing @params */
          i = level;
          while(i > 0) {
            if(strchr(value1, '@')) {
              my_strdup(_ALLOC_ID_, &value1, translate3(value1, 1, lcc[i-1].templ, NULL,  NULL, NULL));
              dbg(1, "2 translate(): lcc[%d].prop_ptr=%s, value1=%s\n", i-1, lcc[i-1].prop_ptr, value1);
            } else break;
            i--;
          }

          tmp=strlen(value1);
          STR_ALLOC(&result, tmp + result_pos, &size);
          memcpy(result+result_pos, value1, tmp+1);
          result_pos+=tmp;
          my_free(_ALLOC_ID_, &value1);
        }
      }
      token_pos = 0;
      if(c == '@' || c == '%') s--;
      else result[result_pos++]=(char)c;
      state=TOK_BEGIN;
    } /* else if(state==TOK_SEP) */
    else if(state==TOK_BEGIN) result[result_pos++]=(char)c;
    if(c=='\0')
    {
      result[result_pos]='\0';
      break;
    }
  } /* while(1) */
  dbg(2, "translate(): returning %s\n", result);
  my_free(_ALLOC_ID_, &token);
  /* resolve spice_get_node patterns.
   * if result is like: 'tcleval(some_string)' pass it thru tcl evaluation so expressions
   * can be calculated */
  my_strdup2(_ALLOC_ID_, &result, spice_get_node(tcl_hook2(result)));

  if(is_expr(result) && inst >= 0) {
    dbg(1, "translate(): expr():%s\n", result);
    my_strdup2(_ALLOC_ID_, &result, eval_expr(
       translate3(result, 1, xctx->inst[inst].prop_ptr, xctx->sym[xctx->inst[inst].ptr].templ,
                              NULL, NULL)));
  }
  return result;
}

const char *translate2(Lcc *lcc, int level, char* s)
{
  static const char *empty="";
  static char *result = NULL;
  int i, escape = 0;
  register int c, state = TOK_BEGIN, space;
  const char *tmp_sym_name;
  size_t sizetok = 0, result_pos = 0, token_pos = 0, size = 0, tmp = 0;
  char  *token = NULL, *value = NULL;

  if(!s) {
    my_free(_ALLOC_ID_, &result);
    return empty;
  }
  size = CADCHUNKALLOC;
  my_realloc(_ALLOC_ID_, &result, size);
  result[0] = '\0';
  dbg(1, "translate2(): s=%s, level=%d\n", s, level);
  while (1) {
    c = *s++;
    if (c == '\\') {
      escape = 1;
      /* we keep backslashes as they should mark end of tokens as for example in: @token1\xxxx@token2
         these backslashes will be 'eaten' at drawing time by translate() */
      /* c = *s++; */
    }
    else escape = 0;
    space = SPACE(c);
    if( state==TOK_BEGIN && (c=='@' || c=='%' ) ) state=TOK_TOKEN;
    else if(state==TOK_TOKEN && token_pos > 1 &&
       ( ( (space || c == '%' || c == '@') ) || escape) ) state = TOK_SEP;
    STR_ALLOC(&result, result_pos, &size);
    STR_ALLOC(&token, token_pos, &sizetok);
    if (state == TOK_TOKEN) token[token_pos++] = (char)c;
    else if (state == TOK_SEP) {
      token[token_pos] = '\0';
      token_pos = 0;

      dbg(1, "translate2(): lcc[%d].prop_ptr=%s token=%s\n", level, lcc[level].prop_ptr, token);
      /* if spiceprefix==0 and token == @spiceprefix then set empty value */
      if(!tclgetboolvar("spiceprefix") && !strcmp(token, "@spiceprefix")) {
        if(value) my_free(_ALLOC_ID_, &value);
        xctx->tok_size = 0;
      } else if(token[0] == '@' && (token[1] == '@' || token[1] == '#')) { /* get rid of pin attribute info */
        if(value) my_free(_ALLOC_ID_, &value);
        xctx->tok_size = 0;
      } else {
        my_strdup2(_ALLOC_ID_, &value, get_tok_value(lcc[level].prop_ptr, token + 1, 0));
        /* propagate %xxx tokens to upper levels if no value found */
        if(!value[0]  && token[0] == '%') {
          my_strdup2(_ALLOC_ID_, &value, token + 1);
          xctx->tok_size = 1; /* just to tell %xxx token was found */
        }
        dbg(1, "translate2(): lcc[%d].prop_ptr=%s value=%s\n", level, lcc[level].prop_ptr, value);
      }
      if(xctx->tok_size && value[0]) {
        i = level;
        /* recursive substitution of value using parent level prop_str attributes */
        while(i > 1) {
          const char *upperval = get_tok_value(lcc[i-1].prop_ptr, value, 0);
          dbg(1, "translate2(): lcc[%d].prop_ptr=%s upperval=%s\n", i-1, lcc[i-1].prop_ptr, upperval);
          if(xctx->tok_size && upperval[0]) {
            my_strdup2(_ALLOC_ID_, &value, upperval);
          } else {
            break;
          }
          i--;
        }
        tmp = strlen(value);
        STR_ALLOC(&result, tmp + 1 + result_pos, &size); /* +1 to add leading '%' */
        /* prefix substituted token with a '%' so it will be recognized by translate()
         * for last level translation with instance placement prop_ptr attributes at
         * drawing/netlisting time. */
        memcpy(result + result_pos , "%", 1);
        memcpy(result + result_pos + 1 , value, tmp + 1);
        result_pos += tmp + 1;
      }
      else if (strncmp(token, "@spice_get_voltage", 18) == 0 ||
               strncmp(token, "@spice_get_current", 18) == 0) { /* return unchanged */
        tmp = strlen(token);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result + result_pos, token, tmp + 1);
        result_pos += tmp;
      }
      else if(strcmp(token,"@path")==0) {
        char *path = NULL;
        my_strdup2(_ALLOC_ID_, &path, "@path@name\\.");
        if(level > 1) { /* add parent LCC instance names (X1, Xinv etc) */
          int i;
          for(i = 1; i <level; ++i) {
            const char *instname = get_tok_value(lcc[i].prop_ptr, "name", 0);
            dbg(0, "adding %s to %s\n", instname, path);
            my_strcat(_ALLOC_ID_, &path, instname);
            my_strcat(_ALLOC_ID_, &path, ".");
          }
        }
        dbg(1, "path=%s\n", path);
        tmp=strlen(path);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result+result_pos, path, tmp+1);
        my_free(_ALLOC_ID_, &path);
        result_pos+=tmp;
      }
      else if (strcmp(token, "@symname") == 0) {
        tmp_sym_name = lcc[level].symname ? get_cell(lcc[level].symname, 0) : "";
        tmp = strlen(tmp_sym_name);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result + result_pos, tmp_sym_name, tmp + 1);
        result_pos += tmp;
      }
      else if (strcmp(token, "@symname_ext") == 0) {
        tmp_sym_name = lcc[level].symname ? get_cell_w_ext(lcc[level].symname, 0) : "";
        tmp = strlen(tmp_sym_name);
        STR_ALLOC(&result, tmp + result_pos, &size);
        memcpy(result + result_pos, tmp_sym_name, tmp + 1);
        result_pos += tmp;
      }
      if (c == '%' || c == '@') s--; /* push back to input for next token */
      else result[result_pos++] = (char)c;
      state = TOK_BEGIN;
    }
    else if (state == TOK_BEGIN) result[result_pos++] = (char)c;
    if (c == '\0') {
      result[result_pos] = '\0';
      break;
    }
  } /* while(1) */
  my_free(_ALLOC_ID_, &token);
  my_free(_ALLOC_ID_, &value);
  dbg(1, "translate2(): result=%s\n", result);
  /* return tcl_hook2(result); */
  return result;
}



/* substitute given tokens in a string with their corresponding values
 * ex.: name=@name w=@w l=@l ---> name=m112 w=3e-6 l=0.8e-6
 * using s1, s2, s3 in turn to resolve @tokens
 * if no definition for @token is found return @token as is in s
 * if s==NULL return emty string
 * eat_escapes:
 *   bit0 == 0 --> keep escapes
 *        == 1 --> remove escapes
 *   bit1 == 0 --> return unchanged token if no value found in s* strings
 *        == 1 --> return empty token if no definition found in s* strings
 */
const char *translate3(const char *s, int eat_escapes, const char *s1,
                       const char *s2, const char *s3, const char *s4)
{
 static const char *empty="";
 static char *translated_tok = NULL;
 static char *result=NULL; /* safe to keep even with multiple schematics */
 register int c, state=TOK_BEGIN, space;
 char *token=NULL;
 size_t sizetok=0;
 size_t token_pos=0;
 const char *value;
 int i, escape=0;
 size_t found_value = 0;
 const char *escape_pos = NULL;
 const char *sptr[5]; /* 1...4 used */

 if(!s || !xctx) {
   my_free(_ALLOC_ID_, &result);
   my_free(_ALLOC_ID_, &translated_tok);
   return empty;
 }
 xctx->tok_size = 0;
 dbg(1, "---\ntranslate3():\n   s=%s\n   s1=%s\n   s2=%s\n   s3=%s\n   s4=%s\n---\n", s, s1, s2, s3, s4);
 my_strdup2(_ALLOC_ID_, &result, "");
 sptr[1] = s1; sptr[2] = s2; sptr[3] = s3; sptr[4] = s4;
 while(1) {
  c=*s;
  if(c=='\\') {
    escape=1;
    escape_pos = s;
    if(eat_escapes & 1) { s++; c=*s; }
  }
  space=SPACE(c);
  if( state==TOK_BEGIN && (c=='@' || c=='%' ) && !escape  ) state=TOK_TOKEN;
  else if(state==TOK_TOKEN && token_pos > 1 &&
     (
       ( (space  || c == '%' || c == '@') && !escape ) ||
       ( (!space && c != '%' && c != '@') && escape  )
     )
    ) state=TOK_SEP;
  if( s > escape_pos ) escape = 0;
  s++;
  STR_ALLOC(&token, token_pos, &sizetok);
  if(state==TOK_TOKEN) token[token_pos++]=(char)c;
  else if(state==TOK_SEP) {
   found_value = 0;
   token[token_pos]='\0';
   dbg(1, "translate3(): token=|%s|\n", token);
   value = NULL;

   for(i = 1; i <= 4; i++) {
     if(!found_value && sptr[i]) {
       value=get_tok_value(sptr[i], token+1, 0);
       dbg(1, "translate3(): i=%d, value=%s\n", i, value);
       if(xctx->tok_size) found_value = xctx->tok_size;
     }
     else if( sptr[i]) {
       char *v = NULL;
       const char *newval;
       my_strdup2(_ALLOC_ID_, &v, value);
       newval = get_tok_value(sptr[i], v, 0);
       if(xctx->tok_size) {
         value = newval;
       }
       my_free(_ALLOC_ID_, &v);
     }
   }

   if(!found_value) { /* above lines did not find a value for token */
     if((eat_escapes & 2) == 0) {
       /* no definition found -> keep token */
       my_strcat(_ALLOC_ID_, &result, token);
     }
   } else {
     my_strcat(_ALLOC_ID_, &result, value);
   }
   token_pos = 0;
   if(c == '@' || c == '%') s--; /* these token separators are also identifiers for next token: push them back */
   else {
     char ch[2];
     ch[0] = (char)c;
     ch[1] = '\0';
     my_strcat(_ALLOC_ID_, &result, ch);
   }
   state=TOK_BEGIN;
  } /* else if(state==TOK_SEP) */
  else if(state==TOK_BEGIN) {
   char ch[2];
   ch[0] = (char)c;
   ch[1] = '\0';
   my_strcat(_ALLOC_ID_, &result, ch);
  }
  if(c=='\0') {
   break;
  }
 } /* while(1) */
 dbg(2, "translate3(): returning %s\n", result);
 my_free(_ALLOC_ID_, &token);

 /* if result is like: 'tcleval(some_string)' pass it thru tcl evaluation so expressions
  * can be calculated */
 dbg(1, "translate3(): result=|%s|\n", result);
 my_strdup2(_ALLOC_ID_, &translated_tok, tcl_hook2(result));
 xctx->tok_size = found_value;
 return translated_tok;
}

