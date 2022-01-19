# Setup League Client
[![Daily Test (@ea5ea07)](https://github.com/mikaeldui/setup-league-client/actions/workflows/daily-test.ea5ea07.yml/badge.svg)](https://github.com/mikaeldui/setup-league-client/actions/workflows/daily-test.ea5ea07.yml)
[![Daily Test (@v1)](https://github.com/mikaeldui/setup-league-client/actions/workflows/daily-test.v1.yml/badge.svg)](https://github.com/mikaeldui/setup-league-client/actions/workflows/daily-test.v1.yml)

![image](https://user-images.githubusercontent.com/3706841/149665686-368d3e10-f5cb-4459-8647-0a2021394027.png)

An action for setting up the League of Legends client (a.k.a. League Client/LCU). Good for testing League Client integrations.

**The action requires a Windows runner.**

The setup takes around 5-10 minutes.

## Example

    - name: Setup League Client
      id: league-client
      uses: mikaeldui/setup-league-client@ea5ea0748d459cb8e4bade9d50d2f81b70f009f7
      with:
        username: ${{ secrets.LOL_USERNAME }}
        password: ${{ secrets.LOL_PASSWORD }}
        region: EUW
        
    - name: Test LCU Integration
      run: .\tests.ps1
      shell: pwsh
      env:
        LCU_PASSWORD: ${{ steps.league-client.outputs.lcu-password }}
        LCU_PORT: ${{ steps.league-client.outputs.lcu-port }}
        LCU_DIR: ${{ steps.league-client.outputs.lcu-directory }}
        
## Questions

### Why is the action referenced using a commit in the example?
It's the most [secure and stable][actions-reference-commit] way to reference an action as tags can be moved. This specific commit also has daily tests as you can see in the top. If you prefer you can reference the action with `@v1` to use any fixes automatically.

### Why isn't the region a secret in the example?
The region is being output in the action logs. I haven't found a good way to mask it since it's also being output in base64. The locale (e.g. en_US) is also being output.

### What is an LCU password?
It's the password used when establishing either an HTTPS or a WSS connection to the LCU. It changes everytime the League Client is restarted. Since the League Client can only be accessed from the local machine (or runner) under normal circumstances it's safe to display and good for debugging purposes.

## Thanks

Thanks to [@MingweiSamuel](https://github.com/MingweiSamuel) for his [lcu-schema/update.ps1][lcu-schema-update.ps1] (licensed under the [MIT license][lcu-schema-license]).

## Notice from Riot Games, Inc.
The GitHub Action "[Setup League Client](https://github.com/marketplace/actions/setup-league-client)" by [@mikaeldui](https://github.com/mikaeldui) isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.

[actions-reference-commit]: https://docs.github.com/en/actions/learn-github-actions/workflow-syntax-for-github-actions#jobsjob_idstepsuses
[lcu-schema-update.ps1]: https://github.com/MingweiSamuel/lcu-schema/blob/a309d795ddf0eba093cb6a6f54ffa9238e947f3a/update.ps1
[lcu-schema-license]: https://github.com/MingweiSamuel/lcu-schema/blob/a309d795ddf0eba093cb6a6f54ffa9238e947f3a/LICENSE
