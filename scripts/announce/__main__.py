from scripts.announce.main import main
from scripts.common import get_piped_input, ARGS

if __name__ == "__main__":
    main(ARGS[0], get_piped_input())
