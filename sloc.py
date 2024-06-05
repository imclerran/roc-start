# '''
#     Count source-lines-of-code (SLOC) in project.

#     Counts the total number of lines in all .roc
#     files. This includes white space and comments.
# '''

import os

def file_len(fname):
    with open(fname) as f:
        for i, l in enumerate(f):
            pass
    return i + 1

def truncate(n, decimals=0):
    multiplier = 10 ** decimals
    return int(n * multiplier) / multiplier

sloc = 0
nfiles = 0
dir_tree = os.walk('.')

for root, dirs, files in dir_tree:
    for file in files:
        if file.endswith('.roc'):
            file_path = os.path.join(root, file)
            length = file_len(file_path)
            print('{} lines in {}'.format(length, file_path))
            sloc += length
            nfiles += 1

if nfiles > 0:
    avg = truncate(sloc / nfiles, 1)
else:
    avg = 0

print('\n=========== SLOC ===========')
print('  {} lines in {} files'.format(sloc, nfiles))
print('  avg. file: {} lines'.format(avg))
print('============================')
