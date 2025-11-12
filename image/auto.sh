for f in *.mp4; do
    ffmpeg -i "$f" -vf "fps=10,scale=320:-1:flags=lanczos" "${f%.mp4}.gif"
done
