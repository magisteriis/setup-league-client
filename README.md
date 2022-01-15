# Install League of Legends
[![CI](https://github.com/mikaeldui/install-league-of-legends/actions/workflows/install.yml/badge.svg)](https://github.com/mikaeldui/install-league-of-legends/actions/workflows/install.yml)
An action for installing League of Legends. Good for testing League Client integrations. The action requires a Windows runner.

## Example

    - name: Install League of Legends
      uses: mikaeldui/install-league-of-legends@v1.1
      with:
        username: ${{ secrets.LOL_USERNAME }}
        password: ${{ secrets.LOL_PASSWORD }}
        region: ${{ secrets.LOL_REGION }}
        
