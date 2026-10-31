"""Execute the productive local resolver in SourcePawn, without SQL or a server."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOLKIT = Path(os.environ.get('STEAMIDTOOLS_ROOT', ROOT.parent/'SteamIDTools'))


def function(text, name):
    start = re.search(r'(?m)^(?:public |stock |static )?\w+ '+re.escape(name)+r'\(', text).start()
    op = text.index('{', start)
    i, depth = op+1, 1
    while depth:
        depth += (text[i] == '{') - (text[i] == '}')
        i += 1
    return text[start:i]


class LocalIdentity(unittest.TestCase):
    def test_real_resolver_vm(self):
        helpers = (ROOT/'addons/sourcemod/scripting/callvote_bans/helpers.sp').read_text()
        # Keep the production context, target setter and format resolver.
        structs = helpers[helpers.index('enum SteamID64_ContinuationType'):helpers.index('int CVB_GetCommandIssuerUserId')]
        source = '#include <steamidtools>\n#define SERVER_INDEX 0\n' + structs
        source += '\nstock void CReplyToCommand(int client, const char[] fmt, any ...) {}\n'
        source += function(helpers, 'CVB_GetCommandIssuerUserId')+'\n'
        source += function(helpers, 'CVB_SetContextTargetFromAccountId')+'\n'
        source += function(helpers, 'ValidateAndConvertSteamIDLocal')+'\n'
        source += '''
public int main() {
    AsyncContext context;
    context.Reset();
    context.ContinuationType = CONTINUE_BAN_IDENTITY;
    context.RestrictionMask = 3;
    char identities[][] = {"76561198008295809", "STEAM_1:1:24015040", "[U:1:48030081]", "48030081"};
    for (int i = 0; i < sizeof(identities); i++) {
        if (ValidateAndConvertSteamIDLocal(0, identities[i], context) != STEAMID_VALIDATION_SUCCESS) return 1;
        if (context.TargetAccountId != 48030081 || !context.HasRequiredDataForBan()) return 2;
        if (!StrEqual(context.TargetSteamId, "STEAM_1:1:24015040")) return 3;
    }
    char invalid[][] = {"0", "4294967296", "76561197960265728", "76561202255233024", "76561198008295809x", "BOT"};
    for (int i = 0; i < sizeof(invalid); i++) {
        if (ValidateAndConvertSteamIDLocal(0, invalid[i], context) != STEAMID_VALIDATION_ERROR) return 4;
    }
    context.AdminUserId = -1;
    if (context.HasRequiredDataForBan() || context.HasRequiredDataForCheck() || context.HasRequiredDataForUnban()) return 5;
    return 0;
}
'''
        with tempfile.TemporaryDirectory() as tmp:
            sp, smx = Path(tmp)/'identity.sp', Path(tmp)/'identity.smx'
            sp.write_text(source)
            compiler = TOOLKIT/'deps/sourcemod-linux/addons/sourcemod/scripting/spcomp'
            result = subprocess.run([str(compiler), str(sp), '-i'+str(ROOT/'addons/sourcemod/scripting/include'), '-i'+str(compiler.parent/'include'), '-o'+str(smx)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            shell, = (TOOLKIT/'deps/sourcepawn/objdir').glob('spshell/**/spshell')
            for flags in ([], ['--disable-jit']):
                result = subprocess.run([str(shell), *flags, str(smx)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
