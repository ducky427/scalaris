#!/bin/bash

# SCALARIS_SRC and SCALARIS_DIR inherited from environment

echo $SCALARIS_SRC
echo $SCALARIS_DIR

echo "syncing scalaris to $SCALARIS_DIR on $(hostname -f)"
[[ -d $SCALARIS_DIR ]] || mkdir -p $SCALARIS_DIR
rsync -ayhxq --executability --delete-after $SCALARIS_SRC/ $SCALARIS_DIR/
(( $? == 0 )) || exit 1