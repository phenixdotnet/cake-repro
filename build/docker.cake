#tool "nuget:?package=Cake.Docker&version=0.7.7"
#reference "./tools/Cake.Docker/lib/netstandard1.6/Cake.Docker.dll"

using Cake.Core.Tooling;

public class DockerHelper
{
	private readonly BuildParameters parameters;
	private readonly string containerName = "buildcontainer";
	private readonly string dockerPort;
	
	public DockerHelper(BuildParameters parameters)
	{
		this.parameters = parameters;
		this.containerName += Guid.NewGuid().ToString();
		
		Random r = new Random();
		this.dockerPort = "230" + r.Next(75, 99);
	}

	public void StartBuildContainer(ICakeContext context)
	{
		context.Information("Starting build container {0} (port: {1})", this.containerName, this.dockerPort);
		
		var runSettings = new DockerRunSettings()
		{
			Detach = true,
			Publish = new string[]{ this.dockerPort + ":2375" },
			Privileged = true,
			Name = containerName,
			Rm = true
		};
		this.SetDockerHostArgument(runSettings);

		context.DockerRun(runSettings, "docker:dind", null, null);
	}

	public void StopBuildContainer(ICakeContext context)
	{
		var stopSettings = new DockerStopSettings();
		this.SetDockerHostArgument(stopSettings);

		context.DockerStop(stopSettings, new string[]{ this.containerName});
	}

	public void BuildAndPushImage(ICakeContext context, string[] tags, string dockerfileDir)
	{
		this.StartBuildContainer(context);
		try
		{
			this.BuildImage(context, tags, dockerfileDir);
			this.PushImage(context, tags);
		}
		finally
		{
			this.StopBuildContainer(context);
		}
	}
	
	public void BuildImage(ICakeContext context, string[] tags, string dockerfileDir)
	{
		var original = context.Environment.WorkingDirectory;
		context.Environment.WorkingDirectory = dockerfileDir;
	
		try
		{
			var buildSettings = new DockerBuildSettings()
			{
				Pull = true,
				ForceRm = true,
				Tag = tags
			};
			this.SetDockerHostArgument(buildSettings, this.dockerPort);		

			context.DockerBuild(buildSettings, ".");
		}
		finally
		{
			context.Environment.WorkingDirectory = original;
		}
	}
	
	private void PushImage(ICakeContext context, string[] tags)
	{
		var pushSettings = new DockerPushSettings();
		this.SetDockerHostArgument(pushSettings, this.dockerPort);
		foreach(var tag in tags)
			context.DockerPush(pushSettings, tag);
	}
	
	private void SetDockerHostArgument(ToolSettings settings, string dockerPort = "2375")
	{
		if(!string.IsNullOrEmpty(parameters.DockerHostConnection))
		{
			settings.ArgumentCustomization = args => args.Prepend(parameters.DockerHostConnection + ":" + dockerPort).Prepend("-H");
		}
	}
}