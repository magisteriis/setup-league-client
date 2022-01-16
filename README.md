# Setup League Client
[![Daily Test](https://github.com/mikaeldui/setup-league-client/actions/workflows/action-test.yml/badge.svg)](https://github.com/mikaeldui/setup-league-client/actions/workflows/action-test.yml)

![image](https://user-images.githubusercontent.com/3706841/149665686-368d3e10-f5cb-4459-8647-0a2021394027.png)

An action for setting up the League of Legends client (a.k.a. League Client/LCU). Good for testing League Client integrations.

**The action requires a Windows runner.**

## Example

    - name: Setup League Client
      id: league-client
      uses: mikaeldui/setup-league-client@v1
      with:
        username: ${{ secrets.LOL_USERNAME }}
        password: ${{ secrets.LOL_PASSWORD }}
        region: ${{ secrets.LOL_REGION }}
        
    - name: Test LCU Integration
      run: .\tests.ps1
      shell: pwsh
      env:
        LCU_PASSWORD: ${{ steps.league-client.outputs.lcu-password }}
        LCU_PORT: ${{ steps.league-client.outputs.lcu-port }}

## Thanks

Thanks to [@MingweiSamuel](https://github.com/MingweiSamuel) for his [lcu-schema/update.ps1](https://github.com/MingweiSamuel/lcu-schema/blob/a309d795ddf0eba093cb6a6f54ffa9238e947f3a/update.ps1) (licensed under the [MIT license](https://github.com/MingweiSamuel/lcu-schema/blob/a309d795ddf0eba093cb6a6f54ffa9238e947f3a/LICENSE).
