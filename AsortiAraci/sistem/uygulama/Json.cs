// Asorti Aracı - küçük JSON okuyucu/yazıcı (.NET Framework 4'te hazır bir tane olmadığı için).
// Nesne -> OrderedDictionary (sıra korunur), dizi -> List<object>, sayı -> double, metin -> string, true/false -> bool, null -> null
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Globalization;
using System.Text;

namespace AsortiAraci
{
    static class Json
    {
        public static object Oku(string s)
        {
            if (s == null) return null;
            int i = 0;
            if (s.Length > 0 && s[0] == '\uFEFF') i = 1;
            Bosluk(s, ref i);
            if (i >= s.Length) return null;
            object v = Deger(s, ref i);
            Bosluk(s, ref i);
            if (i < s.Length) throw new FormatException("JSON sonunda fazla karakter var");
            return v;
        }

        static void Bosluk(string s, ref int i) { while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\r' || s[i] == '\n')) i++; }

        static object Deger(string s, ref int i)
        {
            if (i >= s.Length) throw new FormatException("JSON eksik");
            char c = s[i];
            if (c == '{') return Nesne(s, ref i);
            if (c == '[') return Dizi(s, ref i);
            if (c == '"') return Metin(s, ref i);
            if (c == 't' && Gelen(s, i, "true")) { i += 4; return true; }
            if (c == 'f' && Gelen(s, i, "false")) { i += 5; return false; }
            if (c == 'n' && Gelen(s, i, "null")) { i += 4; return null; }
            return Sayi(s, ref i);
        }

        static bool Gelen(string s, int i, string k) { return i + k.Length <= s.Length && string.CompareOrdinal(s, i, k, 0, k.Length) == 0; }

        static OrderedDictionary Nesne(string s, ref int i)
        {
            OrderedDictionary d = new OrderedDictionary(StringComparer.Ordinal);
            i++;
            Bosluk(s, ref i);
            if (i < s.Length && s[i] == '}') { i++; return d; }
            while (true)
            {
                Bosluk(s, ref i);
                if (i >= s.Length || s[i] != '"') throw new FormatException("JSON anahtar bekleniyordu");
                string k = Metin(s, ref i);
                Bosluk(s, ref i);
                if (i >= s.Length || s[i] != ':') throw new FormatException("JSON ':' bekleniyordu");
                i++;
                Bosluk(s, ref i);
                d[k] = Deger(s, ref i);
                Bosluk(s, ref i);
                if (i < s.Length && s[i] == ',') { i++; continue; }
                if (i < s.Length && s[i] == '}') { i++; return d; }
                throw new FormatException("JSON ',' ya da '}' bekleniyordu");
            }
        }

        static List<object> Dizi(string s, ref int i)
        {
            List<object> l = new List<object>();
            i++;
            Bosluk(s, ref i);
            if (i < s.Length && s[i] == ']') { i++; return l; }
            while (true)
            {
                Bosluk(s, ref i);
                l.Add(Deger(s, ref i));
                Bosluk(s, ref i);
                if (i < s.Length && s[i] == ',') { i++; continue; }
                if (i < s.Length && s[i] == ']') { i++; return l; }
                throw new FormatException("JSON ',' ya da ']' bekleniyordu");
            }
        }

        static string Metin(string s, ref int i)
        {
            StringBuilder sb = new StringBuilder();
            i++;
            while (i < s.Length)
            {
                char c = s[i++];
                if (c == '"') return sb.ToString();
                if (c != '\\') { sb.Append(c); continue; }
                if (i >= s.Length) break;
                char e = s[i++];
                switch (e)
                {
                    case '"': sb.Append('"'); break;
                    case '\\': sb.Append('\\'); break;
                    case '/': sb.Append('/'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case 'u':
                        if (i + 4 > s.Length) throw new FormatException("JSON \\u eksik");
                        sb.Append((char)int.Parse(s.Substring(i, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture));
                        i += 4;
                        break;
                    default: sb.Append(e); break;
                }
            }
            throw new FormatException("JSON metni kapanmadı");
        }

        static object Sayi(string s, ref int i)
        {
            int b = i;
            if (i < s.Length && (s[i] == '-' || s[i] == '+')) i++;
            while (i < s.Length && ((s[i] >= '0' && s[i] <= '9') || s[i] == '.' || s[i] == 'e' || s[i] == 'E' || s[i] == '-' || s[i] == '+')) i++;
            if (i == b) throw new FormatException("JSON değer bekleniyordu");
            return double.Parse(s.Substring(b, i - b), NumberStyles.Float, CultureInfo.InvariantCulture);
        }

        // ---------- yazma ----------
        public static string Yaz(object o) { StringBuilder sb = new StringBuilder(); Yaz(sb, o, false, 0); return sb.ToString(); }
        public static string GuzelYaz(object o) { StringBuilder sb = new StringBuilder(); Yaz(sb, o, true, 0); return sb.ToString(); }

        static void Yaz(StringBuilder sb, object o, bool guzel, int g)
        {
            if (o == null) { sb.Append("null"); return; }
            string s = o as string;
            if (s != null) { Kacis(sb, s); return; }
            if (o is bool) { sb.Append((bool)o ? "true" : "false"); return; }
            if (o is int || o is long || o is short || o is byte || o is uint || o is ulong || o is ushort || o is sbyte) { sb.Append(Convert.ToString(o, CultureInfo.InvariantCulture)); return; }
            if (o is double || o is float || o is decimal)
            {
                double d = Convert.ToDouble(o, CultureInfo.InvariantCulture);
                if (double.IsNaN(d) || double.IsInfinity(d)) sb.Append("null");
                else sb.Append(d.ToString("R", CultureInfo.InvariantCulture));
                return;
            }
            if (o is DateTime) { Kacis(sb, ((DateTime)o).ToString("s", CultureInfo.InvariantCulture)); return; }
            IDictionary dic = o as IDictionary;
            if (dic != null)
            {
                sb.Append('{');
                bool ilk = true;
                foreach (DictionaryEntry e in dic)
                {
                    if (!ilk) sb.Append(',');
                    ilk = false;
                    if (guzel) { sb.Append('\n'); sb.Append(' ', (g + 1) * 2); }
                    Kacis(sb, Convert.ToString(e.Key, CultureInfo.InvariantCulture));
                    sb.Append(guzel ? ": " : ":");
                    Yaz(sb, e.Value, guzel, g + 1);
                }
                if (guzel && !ilk) { sb.Append('\n'); sb.Append(' ', g * 2); }
                sb.Append('}');
                return;
            }
            IEnumerable en = o as IEnumerable;
            if (en != null)
            {
                sb.Append('[');
                bool ilk = true;
                foreach (object x in en)
                {
                    if (!ilk) sb.Append(',');
                    ilk = false;
                    if (guzel) { sb.Append('\n'); sb.Append(' ', (g + 1) * 2); }
                    Yaz(sb, x, guzel, g + 1);
                }
                if (guzel && !ilk) { sb.Append('\n'); sb.Append(' ', g * 2); }
                sb.Append(']');
                return;
            }
            Kacis(sb, Convert.ToString(o, CultureInfo.InvariantCulture));
        }

        static void Kacis(StringBuilder sb, string s)
        {
            sb.Append('"');
            foreach (char c in s)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    default:
                        if (c < 0x20 || c == '\u2028' || c == '\u2029') sb.Append("\\u").Append(((int)c).ToString("x4", CultureInfo.InvariantCulture));
                        else sb.Append(c);
                        break;
                }
            }
            sb.Append('"');
        }

        // ---------- kolay erişim ----------
        public static OrderedDictionary H(params object[] kv)
        {
            OrderedDictionary d = new OrderedDictionary(StringComparer.Ordinal);
            for (int i = 0; i + 1 < kv.Length; i += 2) d[(string)kv[i]] = kv[i + 1];
            return d;
        }

        public static object Al(object o, string anahtar)
        {
            IDictionary d = o as IDictionary;
            if (d == null || !d.Contains(anahtar)) return null;
            return d[anahtar];
        }

        // PowerShell'deki "$($x.y)" gibi: yoksa boş metin, true/false -> True/False
        public static string Str(object o, string anahtar) { return Metin(Al(o, anahtar)); }

        public static string Metin(object v)
        {
            if (v == null) return "";
            if (v is bool) return (bool)v ? "True" : "False";
            if (v is double) return ((double)v).ToString("R", CultureInfo.InvariantCulture);
            return Convert.ToString(v, CultureInfo.InvariantCulture);
        }
    }
}
