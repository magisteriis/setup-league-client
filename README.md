# Setup League Client
[![CI](https://github.com/mikaeldui/install-league-of-legends/actions/workflows/install.yml/badge.svg)](https://github.com/mikaeldui/install-league-of-legends/actions/workflows/install.yml)

![image](https://user-images.githubusercontent.com/3706841/149665686-368d3e10-f5cb-4459-8647-0a2021394027.png)

An action for installing the League of Legends client (a.k.a. LCU). Good for testing League Client integrations. The action requires a Windows runner.

## Example

    - name: Setup League Client
      uses: mikaeldui/setup-league-client@v1
      with:
        username: ${{ secrets.LOL_USERNAME }}
        password: ${{ secrets.LOL_PASSWORD }}
        region: ${{ secrets.LOL_REGION }}        
